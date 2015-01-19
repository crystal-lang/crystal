require "rng/mt19937"

module Random
  DEFAULT = RNG::MT19937.new

  def rand
    DEFAULT.rand
  end

  def rand(x)
    DEFAULT.rand(x)
  end
end

def rand
  Random::DEFAULT.rand
end

def rand(x)
  Random::DEFAULT.rand(x)
end
