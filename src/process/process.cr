lib LibC
  WNOHANG = 0x00000001

  @[ReturnsTwice]
  fun fork : PidT
  fun getpgid(pid : PidT) : PidT
  fun kill(pid : PidT, signal : Int) : Int
  fun getpid : PidT
  fun getppid : PidT
  fun exit(status : Int) : NoReturn

  ifdef x86_64
    alias ClockT = UInt64
  else
    alias ClockT = UInt32
  end

  SC_CLK_TCK = 3

  struct Tms
    utime : ClockT
    stime : ClockT
    cutime : ClockT
    cstime : ClockT
  end

  fun times(buffer : Tms*) : ClockT
  fun sysconf(name : Int) : Long
end

class Process
  def self.exit(status = 0)
    LibC.exit(status)
  end

  def self.pid
    LibC.getpid
  end

  def self.getpgid(pid : Int32)
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

  def self.ppid
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
  def self.fork
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
      @@after_fork_child_callbacks.each(&.call) if run_hooks
    when -1
      raise Errno.new("fork")
    end
    pid
  end

  record Tms, utime, stime, cutime, cstime

  def self.times
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
