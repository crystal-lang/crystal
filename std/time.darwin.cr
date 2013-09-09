lib C
  struct TimeVal
    tv_sec : Int64
    tv_usec : Int32
  end

  struct TimeZone
    tz_minuteswest : Int32
    tz_dsttime : Int32
  end

  fun gettimeofday(tp : TimeVal*, tzp : TimeZone*) : Int32
end


class Time
  def initialize
    C.gettimeofday(out tp, out tzp)
    @seconds = tp.tv_sec + tp.tv_usec / 1e6
  end
end

