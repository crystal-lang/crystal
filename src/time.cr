lib C
  struct Tm
    tm_sec    : Int32
    tm_min    : Int32
    tm_hour   : Int32
    tm_mday   : Int32
    tm_mon    : Int32
    tm_year   : Int32
    tm_wday   : Int32
    tm_yday   : Int32
    tm_isdst  : Int32
    tm_gmtoff : Int64
    tm_zone   : UInt8*
  end

  struct TimeSpec
    tv_sec  : C::TimeT
    tv_nsec : C::TimeT
  end

  struct TimeVal
    tv_sec  : C::TimeT
    tv_usec : Int32
  end

  struct TimeZone
    tz_minuteswest : Int32
    tz_dsttime     : Int32
  end

  fun gettimeofday(tp : TimeVal*, tzp : TimeZone*) : Int32
#   fun mktime(broken_time : Tm*) : Int64
end

ifdef linux
  lib Librt("rt")
    fun clock_gettime(clk_id : Int32, tp : C::TimeSpec*)
  end
end

class Time
  def initialize
    ifdef darwin
      C.gettimeofday(out tp, out tzp)
      @seconds = tp.tv_sec + tp.tv_usec / 1e6
    elsif linux
      Librt.clock_gettime(0, out time)
      @seconds = time.tv_sec + time.tv_nsec / 1e9
    end
  end

  def initialize(seconds)
    @seconds = seconds.to_f64
  end

  def -(other : Number)
    Time.new(to_f - other)
  end

  def -(other : Time)
    to_f - other.to_f
  end

  def to_f
    @seconds
  end

  def to_i
    @seconds.to_i64
  end

  def self.now
    new
  end

  # def self.at(year, month = 1, day = 1, hour = 0, minutes = 0, seconds = 0)
  #   tm :: C::Tm
  #   tm.year = year - 1900
  #   tm.mon = month - 1
  #   tm.mday = day
  #   tm.hour = hour
  #   tm.min = minutes
  #   tm.sec = seconds
  #   tm.isdst = 0
  #   tm.gmtoff = -3
  #   seconds = C.mktime(pointerof(tm))
  #   Time.new(seconds)
  # end
end
