# This is based on the original implementation of MT19937. To get the original version,
# contact <http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html>.
#
# The original copyright notice follows.
#
#   A C-program for MT19937, with initialization improved 2002/1/26.
#   Coded by Takuji Nishimura and Makoto Matsumoto.
#
#   Before using, initialize the state by using init_genrand(seed)
#   or init_by_array(init_key, key_length).
#
#   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions
#   are met:
#
#     1. Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#
#     2. Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#
#     3. The names of its contributors may not be used to endorse or promote
#        products derived from this software without specific prior written
#        permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
#   Any feedback is very welcome.
#   http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
#   email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)

class Random::MT19937
  include Random

  N          =           624
  M          =           397
  MATRIX_A   = 0x9908b0dfu32
  UPPER_MASK = 0x80000000u32
  LOWER_MASK = 0x7fffffffu32

  @mti : Int32

  def initialize(seeds = StaticArray(UInt32, 4).new { Random.new_seed })
    @mt = StaticArray(UInt32, 624).new(0u32)
    @mti = N + 1
    init_by_array(seeds)
  end

  def new_seed(seeds = StaticArray(UInt32, 4).new { Random.new_seed })
    @mti = N + 1
    init_by_array(seeds)
  end

  def self.new(seed : Int)
    seeds = UInt32[1]
    seeds[0] = seed.to_u32
    new(seeds)
  end

  private def init_genrand(seed)
    @mt[0] = seed & 0xffffffffu32
    @mti = 1
    while @mti < N
      @mt[@mti] = (1812433253u32 * (@mt[@mti - 1] ^ (@mt[@mti - 1] >> 30)) + @mti) & 0xffffffffu32
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
      @mt[i] = (@mt[i] ^ ((@mt[i - 1] ^ (@mt[i - 1] >> 30)) * 1664525u32)) + init_keys[j] + j

      i += 1
      j += 1

      if i >= N
        @mt[0] = @mt[N - 1]
        i = 1
      end

      if j >= key_len
        j = 0
      end

      k -= 1
    end

    k = N - 1

    while k > 0
      @mt[i] = (@mt[i] ^ ((@mt[i - 1] ^ (@mt[i - 1] >> 30)) * 1566083941u32)) - i
      i += 1

      if i >= N
        @mt[0] = @mt[N - 1]
        i = 1
      end

      k -= 1
    end

    # Use to_i because substituting 0x80000000 causes SEGV
    @mt[0] = 0x80000000u32
  end

  def next_u
    if @mti >= N
      if @mti == N + 1
        init_genrand(5489u32)
      end

      kk = 0u32

      while kk < N - M
        y = (@mt[kk] & UPPER_MASK) | (@mt[kk + 1] & LOWER_MASK)
        @mt[kk] = @mt[kk + M] ^ (y >> 1) ^ (y % 2 == 0 ? 0 : MATRIX_A)
        kk += 1
      end

      while kk < N - 1
        y = (@mt[kk] & UPPER_MASK) | (@mt[kk + 1] & LOWER_MASK)
        @mt[kk] = @mt[kk + M - N] ^ (y >> 1) ^ (y % 2 == 0 ? 0 : MATRIX_A)
        kk += 1
      end

      y = (@mt[N - 1] & UPPER_MASK) | (@mt[0] & LOWER_MASK)
      @mt[N - 1] = @mt[M - 1] ^ (y >> 1) ^ (y % 2 == 0 ? 0 : MATRIX_A)

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
