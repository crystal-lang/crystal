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
end

module Process
  extend self

  def exit(status = 0)
    C.exit(status)
  end

  def pid
    C.getpid()
  end

  def ppid
    C.getppid()
  end

  def fork(&block)
    pid = self.fork()

    unless pid
      yield
      exit
    end

    pid
  end

  def fork()
    pid = C.fork
    pid = nil if pid == 0
    pid
  end

  make_named_tuple Tms, [utime, stime, cutime, cstime]

  def times
    hertz = C.sysconf(C::SC_CLK_TCK).to_f
    C.times(out tms)
    Tms.new(tms.utime / hertz, tms.stime / hertz, tms.cutime / hertz, tms.cstime / hertz)
  end
end
