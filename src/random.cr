class Random

  class MT19937
    N = 624
    M = 397
    MATRIX_A = 0x9908b0dfu32
    UPPER_MASK = 0x80000000u32
    LOWER_MASK = 0x7fffffffu32

    def initialize(seeds = Array(UInt32).new(4){ Intrinsics.read_cycle_counter.to_u32 })
      @mt = StaticArray(UInt32, 624).new(0u32)
      @mti = N + 1
      init_by_array(seeds)
    end

    private def init_genrand(seed)
      @mt[0] = seed & 0xffffffffu32
      @mti = 1
      while @mti < N
        @mt[@mti] = (1812433253u32 * (@mt[@mti-1] ^ (@mt[@mti-1] >> 30)) + @mti) & 0xffffffffu32
        @mti += 1
      end
    end

    private def init_by_array(init_keys)
      key_len = init_keys.size
      init_genrand 19650218u32

      i = 1
      j = 0
      k = if N > key_len
            N
          else
            key_len
          end

      while k > 0
        @mt[i] = (@mt[i] ^ ((@mt[i-1] ^ (@mt[i-1] >> 30)) * 1664525u32)) + init_keys[j] + j

        i += 1
        j += 1

        if i >= N
          @mt[0] = @mt[N-1]
          i = 1
        end

        if j >= key_len
          j = 0
        end

        k -= 1
      end

      k = N - 1

      while k > 0
        @mt[i] = (@mt[i] ^ ((@mt[i-1] ^ (@mt[i-1] >> 30)) * 1566083941u32)) - i
        i += 1

        if i >= N
          @mt[0] = @mt[N-1]
          i = 1
        end

        k -= 1
      end

      # Use to_i because substituting 0x80000000 causes SEGV
      @mt[0] = 0x80000000u32
    end

    def next_number()
      mag01 = [0, MATRIX_A]

      if @mti >= N
        if @mti == N + 1
          init_genrand(5489u32)
        end

        kk = 0u32

        while kk < N - M
          y = (@mt[kk] & UPPER_MASK) | (@mt[kk+1] & LOWER_MASK)
          @mt[kk] = @mt[kk+M] ^ (y >> 1) ^ mag01[y%2]
          kk += 1
        end

        while kk < N - 1
          y = (@mt[kk] & UPPER_MASK) | (@mt[kk+1] & LOWER_MASK)
          @mt[kk] = @mt[kk+M-N] ^ (y >> 1) ^ mag01[y%2]
          kk += 1
        end

        y = (@mt[N-1] & UPPER_MASK) | (@mt[0] & LOWER_MASK)
        @mt[N-1] = @mt[M-1] ^ (y >> 1) ^ mag01[y%2]


        @mti = 0
      end

      y = @mt[@mti]
      @mti += 1

      y ^= (y >> 11)
      y ^= ((y << 7) & 0x9d2c5680u32)
      y ^= ((y << 15) & 0xefc60000u32)
      y ^= (y >> 18)

      y
    end
  end

  def initialize(seeds)
    @engine = MT19937.new(seeds)
  end

  def initialize()
    @engine = MT19937.new
  end

  def srand(x : Int)
    init_by_array([x])
  end

  def rand()
    # Devided by 2^32-1
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

  def self.srand(x)
    DEFAULT_RANDOM.srand(x)
  end
end

def rand()
  Random.rand
end

def rand(x)
  Random.rand(x)
end

def srand(x)
  Random.srand(x)
end

