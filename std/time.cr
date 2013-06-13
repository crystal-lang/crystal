lib C
  struct TimeSpec
    tv_sec, tv_nsec : Int64
  end
  fun clock_gettime(clk_id : Int32, tp : TimeSpec*)
end

class Time
  def initialize
    C.clock_gettime(0, out @time)
  end

  def to_f
    @time.tv_sec + @time.tv_nsec / 1e9
  end

  def to_i
    @time.tv_sec.to_i
  end

  def self.now
    Time.new.to_f
  end
end
