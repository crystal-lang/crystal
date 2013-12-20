# lib C
#   struct Tm
#     sec : Int32
#     min : Int32
#     hour : Int32
#     mday : Int32
#     mon : Int32
#     year : Int32
#     wday : Int32
#     yday : Int32
#     isdst : Int32
#     gmtoff : Int32
#     zone : Char*
#   end

#   fun mktime(broken_time : Tm*) : Int64
# end

ifdef darwin
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
elsif linux
  lib Librt("rt")
    struct TimeSpec
      tv_sec : C::SizeT
      tv_nsec : C::SizeT
    end
    fun clock_gettime(clk_id : Int32, tp : TimeSpec*)
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
