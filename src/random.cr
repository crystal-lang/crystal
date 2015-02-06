require "random/mt19937"

module Random
  DEFAULT = MT19937.new

  def self.new_seed
    Intrinsics.read_cycle_counter.to_u32
  end

  abstract def next_u32

  def next_bool
    next_u32.even?
  end

  def next_int
    next_u32.to_i32
  end

  def next_float
    # Divided by 2^32-1
    next_u32 * (1.0/4294967295.0)
  end

  def rand
    next_float
  end

  def rand(x : Int)
    if x > 0
      (next_u32 % x).to_i32
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

  def self.rand
    DEFAULT.rand
  end

  def self.rand(x)
    DEFAULT.rand(x)
  end
end

def rand
  Random.rand
end

def rand(x)
  Random.rand(x)
end
