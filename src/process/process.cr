lib LibC
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
    LibC.getpid()
  end

  def self.getpgid(pid : Int32)
    ret = LibC.getpgid(pid)
    raise Errno.new(ret) if ret < 0
    ret
  end

  def self.kill(signal : Signal, *pids : Int)
    pids.each do |pid|
      ret = LibC.kill(pid.to_i32, signal.value)
      raise Errno.new(ret) if ret < 0
    end
    0
  end

  def self.ppid
    LibC.getppid()
  end

  def self.fork(&block)
    pid = self.fork()

    unless pid
      yield
      exit
    end

    pid
  end

  def self.fork
    pid = LibC.fork
    case pid
    when 0
      pid = nil
      Scheduler.after_fork
    when -1
      raise Errno.new("fork")
    end
    pid
  end

  def self.waitpid(pid)
    if LibC.waitpid(pid, out exit_code, 0) == -1
      raise Errno.new("Error during waitpid")
    end

    exit_code
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

def fork()
  Process.fork()
end

require "./*"
