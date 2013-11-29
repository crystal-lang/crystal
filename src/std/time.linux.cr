lib Librt("rt")
  struct TimeSpec
    tv_sec, tv_nsec : Int64
  end
  fun clock_gettime(clk_id : Int32, tp : TimeSpec*)
end

class Time
  def initialize
    Librt.clock_gettime(0, out time)
    @seconds = time.tv_sec + time.tv_nsec / 1e9
  end
end
