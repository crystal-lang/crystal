require "random/mt19937"

class Random
  def initialize(engine_class, seed)
    @engine = engine_class.new(seed)
  end

  def initialize(engine_class = MT19937)
    @engine = engine_class.new
  end

  def rand()
    # Divided by 2^32-1
    @engine.next_number * (1.0/4294967295.0)
  end

  def rand(x : Int)
    if x > 0
      @engine.next_number % x
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

  DEFAULT_RANDOM = Random.new

  def self.new_seed()
    Intrinsics.read_cycle_counter.to_u32
  end

  def self.rand()
    DEFAULT_RANDOM.rand
  end

  def self.rand(x)
    DEFAULT_RANDOM.rand(x)
  end
end

def rand()
  Random.rand
end

def rand(x)
  Random.rand(x)
end

