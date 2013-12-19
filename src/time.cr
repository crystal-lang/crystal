require "time.linux" if linux
require "time.darwin" if darwin

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

class Time
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
