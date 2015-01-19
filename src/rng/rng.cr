class RNG
  def next_float
    # Divided by 2^32-1
    next_int * (1.0/4294967295.0)
  end

  alias_method :rand, :next_float

  def rand(x : Int)
    if x > 0
      next_int % x
    else
      raise ArgumentError.new "incorrect rand value: #{x}"
    end
  end

  def rand(x : Range(Int32, Int32))
    span = x.end - x.begin
    span += 1 unless x.excludes_end?
    if span > 0
      x.begin + rand(span)
    else
      raise ArgumentError.new "incorrect rand value: #{x}"
    end
  end

  def self.new_seed
    Intrinsics.read_cycle_counter.to_u32
  end
end
