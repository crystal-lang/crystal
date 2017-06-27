require "secure_random"

# Hasher usable for `def hash(hasher)` should satisfy protocol:
#   class MyHasher
#     # Value should implement commutative `+` for `Hash#hash(hasher)`
#     alias Value
#
#     # must be implemented to mix sizes of collections, and pointers (object_id)
#     def raw(v : Int::Primitive)
#       # mutate
#       self
#     end
#
#     # must be implemented for Hash#hash
#     def raw(v : Value)
#     end
#
#     def <<(b : Bytes)
#       # mutate
#       self
#     end
#
#     def <<(n : Nil)
#       # mutate
#       self
#     end
#
#     def <<(v)
#       # v.hash will mutate hasher
#       v.hash(self)
#       self
#     end
#
#     # digest returns hashsum for current state without state mutation
#     def digest : Value
#     end
#
#     # should be implemented for `Hash#hash(hasher)`
#     def clone_build
#       with_state_copy do |copy|
#         yield copy
#         copy.digest
#       end
#     end
#   end

# StdHasher used as standard hasher in `Object#hash`
# It have to provide defenense against HashDos, and be reasonably fast.
# To protect against HashDos, it is seeded with secure random, and have
# permutation that hard to forge without knowing seed and seeing hash digest.
#
# Also it has specialized methods for primitive keys with different seeds.
struct StdHasher
  alias Value = UInt32

  @@seed = StaticArray(UInt32, 7).new { |i| 0_u32 }
  buf = pointerof(@@seed).as(Pointer(UInt8))
  SecureRandom.random_bytes(buf.to_slice(sizeof(typeof(@@seed))))

  private def initialize(@h : Pointer(Impl))
  end

  def initialize
    @h = Pointer(Impl).malloc(1, Impl.new(@@seed[0], @@seed[1]))
  end

  protected def initialize(a, b)
    @h = Pointer(Impl).malloc(1, Impl.new(a, b))
  end

  def self.build
    h = Impl.new(@@seed[0], @@seed[1])
    s = new(pointerof(h))
    yield s
    s.digest
  end

  def self.hashit(v)
    build do |s|
      s << v
    end
  end

  protected def self.build(a, b)
    h = Impl.new(a, b)
    s = new(pointerof(h))
    yield s
    s.digest
  end

  def clone_build
    self.class.build(@h.value.a, @h.value.b) do |s|
      yield s
    end
  end

  def clone
    self.class.new(@h.value.a, @h.value.b)
  end

  def <<(v : Nil)
    @h.value.permute_nil(@@seed[2])
    self
  end

  # mix raw value without number normalizing
  def raw(v : Int8 | Int16 | Int32 | UInt8 | UInt16 | UInt32)
    @h.value.permute(v.to_u32, @@seed[2])
    self
  end

  # mix raw value without number normalizing
  def raw(v : Int64 | UInt64)
    @h.value.permute((v >> 32).to_u32, @@seed[2])
    @h.value.permute(v.to_u32, @@seed[2])
    self
  end

  def <<(v : Int8 | Int16 | UInt8 | UInt16)
    @h.value.permute(v.to_u32, @@seed[2])
    self
  end

  def <<(b : Bytes)
    @h.value.permute(b, @@seed[2])
    self
  end

  def <<(v)
    v.hash(self)
    self
  end

  def remix(v : Value)
    self << Raw32.new(v)
  end

  def digest
    @h.value.digest(@@seed[3])
  end

  private struct Impl
    getter a : UInt32 = 0_u32
    getter b : UInt32 = 0_u32

    def initialize(@a : UInt32, @b : UInt32)
    end

    def permute(v : UInt32, s : UInt32)
      permute(v, s, pointerof(@a), pointerof(@b))
    end

    def permute_nil(s : UInt32)
      @a += s | 1
      # LFSR
      mx = (@b.to_i32 >> 31).to_u32 & 0xa8888eef_u32
      @b = (@b << 1) ^ mx
    end

    def digest(seed)
      a, b = @a, @b
      b += seed
      a ^= a >> 15
      b ^= b >> 16
      a *= 0xb8b34b2d_u32
      b *= 0x52c6a2d9_u32
      a ^= a >> 17
      b ^= b >> 16
      b + a
    end

    def permute(buf : Bytes, s : UInt32)
      bsz = buf.size
      v = bsz.to_u32 << 24
      u = buf.to_unsafe
      a, b = @a, @b
      i = bsz.unsafe_div 4
      while i > 0
        permute(u.as(Pointer(UInt32)).value, s, pointerof(a), pointerof(b))
        u += 4
        i -= 1
      end
      r = (bsz & 3).to_u32
      if r != 0
        v |= u[0].to_u32 | (u[r/2].to_u32 << 8) | (u[r - 1].to_u32 << 16)
      end
      permute(v, s, pointerof(a), pointerof(b))
      @a, @b = a, b
      self
    end

    private def permute(v : UInt32, s : UInt32, aa : Pointer(UInt32), bb : Pointer(UInt32))
      a, b = aa.value, bb.value
      v ^= s
      v *= 0xb8b34b2d_u32
      a += v
      a = rotl(a, 13)
      b ^= a + s
      b *= 9
      aa.value, bb.value = a, b
      nil
    end

    private def rotl(v : UInt32, sh)
      (v << sh) | (v >> (sizeof(UInt32) * 8 - sh))
    end
  end

  # separate method for faster default hashtable with UInt32, Int32, Float32 and Symbol keys
  def self.fasthash(v : UInt32 | Int32 | UInt16 | Int16 | UInt8 | Int8)
    h = @@seed[4] + v.to_u32
    h ^= h >> 16
    h *= 0x52c6a2d9_u32
    h ^= (h >> 16)
    h *= 0xb8b34b2d_u32
    h += @@seed[5]
    h ^ (h >> 16)
  end

  # separate method for faster default hashtable with UInt64, Int64 and Float64 keys
  def self.fasthash(v : UInt64 | Int64)
    high = (v >> 32).to_u32
    if high != 0
      h = @@seed[5] + high
      h ^= h >> 16
      h *= 0xb8b34b2d_u32
    else
      h = 0_u32
    end
    h += @@seed[4] + v.to_u32
    h ^= h >> 16
    h *= 0x52c6a2d9_u32
    h ^= h >> 16
    h *= 0xb8b34b2d_u32
    h += @@seed[5]
    h ^ (h >> 16)
  end

  # unseeded is used for types that are used in early startup
  def self.unseeded(v : Int8 | Int16 | UInt8 | UInt16 | Int32 | UInt32)
    h = v.to_u32
    h ^= h >> 16
    h *= 0x52c6a2d9_u32
    h ^ (h >> 16)
  end

  # unseeded is used for types that are used in early startup
  def self.unseeded(v : Int64 | UInt64)
    h = (v >> 32).to_u32
    h ^= h >> 16
    h *= 0xb8b34b2d_u32
    h += v.to_u32
    h ^= h >> 16
    h *= 0x52c6a2d9_u32
    h ^ (h >> 16)
  end
end
