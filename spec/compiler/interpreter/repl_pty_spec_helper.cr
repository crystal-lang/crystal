# Shared helpers for specs that drive the real `crystal i` REPL over a
# PTY (the reply line editor needs a TTY with a non-zero window size).
#
# The paste rule (from the reply line editor's CharReader): the line text
# and the Enter key must be two separate writes with a pause between them,
# or the editor treats them as a paste and never submits.

module ReplPty
  ANSI_ESCAPES = /\e\[[0-9;?]*[A-Za-z]/

  def self.compiler_bin : String
    bin = File.expand_path("../../../.build/crystal", __DIR__)
    File.exists?(bin) ? bin : `sh -c 'command -v crystal'`.chomp
  end

  def self.env : Hash(String, String)
    src = File.expand_path("../../../src", __DIR__)
    ENV.to_h.merge({"CRYSTAL_PATH" => src, "CRYSTAL_INTERPRETER_SKIP_BANNER" => "1"})
  end
end

@[Link("util")]
lib ReplPtyLib
  struct Winsize
    ws_row    : UInt16
    ws_col    : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end

  fun openpty(amaster : Int32*, aslave : Int32*, name : UInt8*,
              termios : Void*, win : Winsize*) : Int32
end

# Waits until the accumulated output contains `want`, failing at the
# deadline (a hung/deadlocked REPL times out).
class ReplPtySession
  getter process : Process?
  @master : IO::FileDescriptor
  @buf = IO::Memory.new

  def initialize(bin : String)
    win = ReplPtyLib::Winsize.new(ws_row: 50, ws_col: 500, ws_xpixel: 0, ws_ypixel: 0)
    ret = ReplPtyLib.openpty(out master, out slave, Pointer(UInt8).null,
      Pointer(Void).null, pointerof(win))
    raise "openpty failed" unless ret == 0
    slave_io = IO::FileDescriptor.new(slave)
    @master = IO::FileDescriptor.new(master)
    @master.read_timeout = 0.2.seconds
    # The interpreter's line editor needs each write flushed immediately,
    # or the bytes never reach the PTY.
    @master.sync = true
    @process = Process.new(bin, {"i"}, env: ReplPty.env,
      input: slave_io, output: slave_io, error: slave_io, chdir: __DIR__)
    slave_io.close
  end

  def output : String
    @buf.to_s.gsub(ReplPty::ANSI_ESCAPES, "")
  end

  # Read until `want` shows up in the output, or fail at `deadline`.
  def read_until(what : String, want : String, deadline : Time::Span) : Nil
    finish = Time.instant + deadline
    while Time.instant < finish
      begin
        slice = Bytes.new(4096)
        if (n = @master.read(slice)) > 0
          @buf.write(slice[0, n])
          next
        end
        # EOF: interpreter died
        break
      rescue IO::TimeoutError
        # quiet window
      end
      return if output.includes?(want)
    end
    return if output.includes?(want)
    fail "REPL over PTY timed out waiting for #{what}:\n#{output.inspect[0...2000]}"
  end

  # The line text and the Enter key must be two separate writes, or the
  # editor treats them as a paste and never submits.
  def submit(line : String) : Nil
    @master.write(line.to_slice)
    sleep 0.3.seconds
    @master.write("\r".to_slice)
  end

  def close : Nil
    if process = @process
      begin
        submit("exit")
      rescue IO::Error
      end
      20.times do
        break unless process.exists?
        sleep 0.05.seconds
      end
      process.terminate rescue nil
    end
    @master.close rescue nil
  end
end
