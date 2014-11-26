lib C
  @:ReturnsTwice
  fun fork : Int32

  fun getpid : Int32
  fun getppid : Int32
  fun exit(status : Int32) : NoReturn

  ifdef x86_64
    ClockT = UInt64
  else
    ClockT = UInt32
  end

  SC_CLK_TCK = 3

  struct Tms
    utime : ClockT
    stime : ClockT
    cutime : ClockT
    cstime : ClockT
  end

  fun times(buffer : Tms*) : ClockT
  fun sysconf(name : Int32) : Int64

  fun sleep(seconds : UInt32) : UInt32
  fun usleep(useconds : UInt32) : UInt32
end

module Process
  def self.exit(status = 0)
    C.exit(status)
  end

  def self.pid
    C.getpid()
  end

  def self.ppid
    C.getppid()
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
    pid = C.fork
    pid = nil if pid == 0
    pid
  end

  def self.waitpid(pid)
    if C.waitpid(pid, out exit_code, 0) == -1
      raise Errno.new("Error during waitpid")
    end

    exit_code >> 8
  end

  record Tms, utime, stime, cutime, cstime

  def self.times
    hertz = C.sysconf(C::SC_CLK_TCK).to_f
    C.times(out tms)
    Tms.new(tms.utime / hertz, tms.stime / hertz, tms.cutime / hertz, tms.cstime / hertz)
  end
end

def fork
  Process.fork { yield }
end

def fork()
  Process.fork()
end

def sleep(seconds : Int)
  if seconds < 0
    raise ArgumentError.new "sleep seconds must be positive"
  end
  C.sleep seconds.to_u32
end

def sleep(seconds : Float)
  if seconds < 0
    raise ArgumentError.new "sleep seconds must be positive"
  end
  C.usleep (seconds * 1E6).to_u32
end

require "./*"
