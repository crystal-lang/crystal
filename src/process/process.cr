lib LibC
  WNOHANG = 0x00000001

  @[ReturnsTwice]
  fun fork : PidT
  fun getpgid(pid : PidT) : PidT
  fun kill(pid : PidT, signal : Int) : Int
  fun getpid : PidT
  fun getppid : PidT
  fun setsid : PidT
  fun getsid(pid : PidT) : PidT
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

  def self.pid : LibC::PidT
    LibC.getpid
  end

  def self.getpgid(pid : Int32) : LibC::PidT
    ret = LibC.getpgid(pid)
    raise Errno.new(ret) if ret < 0
    ret
  end

  def self.setsid
    LibC.setsid
  end

  def self.sid(pid : Int32 = 0)
    LibC.getsid(pid)
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

  # Daemonizes the process
  #
  # This method detaches the process from the terminal so the program
  # may run in the backgound without the terminal.
  #
  # By default STDIN, STDOUT, and STDERR are redirected to /dev/null.
  # They may be redirected to a file to be read-in by STDIN, or written-
  # to by STDOUT and STDERR.
  #
  # By default, the daemonized process will change to root as a working directory.
  # Another working directory can be provided.
  def self.daemonize(stdin : String = "/dev/null", stdout : String = "/dev/null", stderr : String = "/dev/null", dir : String = "/")
    exit if fork
    setsid
    exit if fork
    Dir.cd(dir)
    STDIN.reopen(File.open(stdin, "a+"))
    STDOUT.reopen(File.open(stdout, "a"))
    STDERR.reopen(File.open(stderr, "a"))
  end
end

def fork
  Process.fork { yield }
end

def fork
  Process.fork
end

require "./*"
