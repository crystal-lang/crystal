# (c) Bob Jenkins, March 1996, Public Domain
# You may use this code in any way you wish, and it is free.  No warrantee.
# http://burtleburtle.net/bob/rand/isaacafa.html

class Random::ISAAC
  include Random

  private getter counter
  private getter aa
  private getter bb
  private getter cc

  def initialize(seeds = StaticArray(UInt32, 8).new { Random.new_seed })
    @rsl = StaticArray(UInt32, 256).new { 0_u32 }
    @mm = StaticArray(UInt32, 256).new { 0_u32 }
    @counter = 0
    @aa = @bb = @cc = 0_u32
    init_by_array(seeds)
  end

  def new_seed(seeds = StaticArray(UInt32, 8).new { Random.new_seed })
    @aa = @bb = @cc = 0_u32
    init_by_array(seeds)
  end

  def next_u
    if (@counter -= 1) == -1
      isaac
      @counter = 255
    end
    @rsl[counter]
  end

  private def isaac
    @cc += 1
    @bb += cc

    256.times do |i|
      @aa ^= case i % 4
             when 0 then aa << 13
             when 1 then aa >> 6
             when 2 then aa << 2
             else        aa >> 16
             end
      x = @mm[i]
      @aa = @mm[(i + 128) % 256] + aa
      @mm[i] = y = @mm[(x >> 2) % 256] + aa + bb
      @rsl[i] = @bb = @mm[(y >> 10) % 256] + x
    end
  end

  private def init_by_array(seeds)
    seed_len = seeds.size
    256.times { |i| @rsl[i] = i < seed_len ? seeds[i].to_u32 : 0_u32 }

    a = b = c = d = e = f = g = h = 0x9e3779b9_u32

    mix = ->{
      a ^= b << 11; d += a; b += c
      b ^= c >> 2; e += b; c += d
      c ^= d << 8; f += c; d += e
      d ^= e >> 16; g += d; e += f
      e ^= f << 10; h += e; f += g
      f ^= g >> 4; a += f; g += h
      g ^= h << 8; b += g; h += a
      h ^= a >> 9; c += h; a += b
    }
    4.times(&mix)

    scramble = ->(seed : StaticArray(UInt32, 256)) {
      0.step(to: 255, by: 8) do |i|
        a += seed[i]; b += seed[i + 1]; c += seed[i + 2]; d += seed[i + 3]
        e += seed[i + 4]; f += seed[i + 5]; g += seed[i + 6]; h += seed[i + 7]
        mix.call
        @mm[i] = a; @mm[i + 1] = b; @mm[i + 2] = c; @mm[i + 3] = d
        @mm[i + 4] = e; @mm[i + 5] = f; @mm[i + 6] = g; @mm[i + 7] = h
      end
    }

    scramble.call(@rsl)
    scramble.call(@mm)

    isaac
    @counter = 256
  end
end
