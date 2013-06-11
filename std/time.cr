lib C
  struct TimeSpec
    tv_sec, tv_nsec : Int64
  end
  fun clock_gettime(clk_id : Int32, tp : TimeSpec*)
end

class Time
  BILLION = 1000000000.0

  def initialize
    @time = C::TimeSpec.new
    C.clock_gettime(0, @time.ptr)
  end

  def to_f
    @time.tv_sec + @time.tv_nsec / BILLION
  end

  def to_i
    @time.tv_sec.to_i
  end

  def self.now
    Time.new.to_f
  end
end
