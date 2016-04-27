require "c/signal"
require "c/stdlib"
require "c/sys/times"
require "c/sys/wait"
require "c/unistd"

class Process
  def self.exit(status = 0)
    LibC.exit(status)
  end

  def self.pid : LibC::PidT
    LibC.getpid
  end

  def self.getpgid(pid : Int32) : LibC::PidT
    ret = LibC.getpgid(pid)
    raise Errno.new(ret) if ret < 0
    ret
  end

  def self.kill(signal : Signal, *pids : Int)
    pids.each do |pid|
      ret = LibC.kill(pid, signal.value)
      raise Errno.new(ret) if ret < 0
    end
    nil
  end

  def self.ppid : LibC::PidT
    LibC.getppid
  end

  # Returns a `Process`.
  def self.fork
    pid = fork_internal do
      with self yield self
    end
    Process.new pid
  end

  # Returns a `Process`.
  def self.fork : self?
    if pid = fork_internal
      Process.new pid
    else
      nil
    end
  end

  protected def self.fork_internal(run_hooks : Bool = true, &block)
    pid = self.fork_internal(run_hooks)

    unless pid
      begin
        yield
        LibC._exit 0
      rescue ex
        ex.inspect STDERR
        STDERR.flush
        LibC._exit 1
      ensure
        LibC._exit 254 # not reached
      end
    end

    pid
  end

  # run_hooks should ALWAYS be true unless exec* is used immediately after fork.
  # Channels, IO and other will not work reliably if run_hooks is false.
  protected def self.fork_internal(run_hooks : Bool = true)
    pid = LibC.fork
    case pid
    when 0
      pid = nil
      Process.after_fork_child_callbacks.each(&.call) if run_hooks
    when -1
      raise Errno.new("fork")
    end
    pid
  end

  record Tms, utime : Float64, stime : Float64, cutime : Float64, cstime : Float64

  def self.times : Tms
    hertz = LibC.sysconf(LibC::SC_CLK_TCK).to_f
    LibC.times(out tms)
    Tms.new(tms.utime / hertz, tms.stime / hertz, tms.cutime / hertz, tms.cstime / hertz)
  end
end

def fork
  Process.fork { yield }
end

def fork
  Process.fork
end

require "./*"
