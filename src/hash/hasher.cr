require "crystal/system/random"

# Hasher usable for `def hash(hasher)` should satisfy protocol:
# ```
# class MyHasher
#   # Value should implement commutative `+` for `Hash#hash(hasher)`
#   alias Value
#
#   # must be implemented to mix sizes of collections, and pointers (object_id)
#   def raw(v : Int::Primitive)
#     # mutate
#     nil
#   end
#
#   # must be implemented for Hash#hash
#   def raw(v : Value)
#     # mutate
#     nil
#   end
#
#   def <<(b : Bytes)
#     # mutate
#     nil
#   end
#
#   def <<(n : Nil)
#     # mutate
#     nil
#   end
#
#   def <<(v)
#     # v.hash will return hasher
#     # if hasher is a struct, then it will be copy
#     copy_from v.hash(self)
#     nil
#   end
#
#   # digest returns hashsum for current state without state mutation
#   def digest : Value
#   end
#
#   # should be implemented for `Hash#hash(hasher)`
#   def clone
#     copy_of_current_state
#   end
# end
# ```

class Hash
  # Hasher used as standard hasher in `Object#hash`
  struct Hasher
    # Type for Hash::Hasher#digest
    alias Value = UInt32

    @@seed = uninitialized StaticArray(UInt32, 1)
    buf = pointerof(@@seed).as(Pointer(UInt8))
    Crystal::System::Random.random_bytes(buf.to_slice(sizeof(typeof(@@seed))))

    protected getter a : UInt32 = 0_u32

    # Construct hasher with per-process seed.
    def initialize
      @a = @@seed[0]
    end

    # Construct hasher with custom seed.
    def initialize(@a : UInt32)
    end

    # Calculate hashsum for value
    def self.hashit(value) : Value
      s = new(@@seed[0])
      s << value
      s.digest
    end

    # Make copy of self.
    #
    # Primary usage is for `Hash#hash` calculation.
    def clone : self
      self.class.new(@a)
    end

    # Mix nil to state
    def <<(v : Nil) : Nil
      permute_nil()
      nil
    end

    # Mix raw value without number normalizing
    def raw(v : Int8 | UInt8) : Nil
      permute(v.to_u8)
      nil
    end

    # Mix raw value without number normalizing
    def raw(v : Int16 | Int32 | UInt16 | UInt32) : Nil
      permute(v.to_u32)
      nil
    end

    # Mix raw value without number normalizing
    def raw(v : Int64 | UInt64) : Nil
      high = (v >> 32).to_u32
      # This condition here cause of some 32bit issue in LLVM binding,
      # so compiler_spec doesn't pass without it.
      # Feel free to comment and debug.
      if high != 0_u32
        permute(high)
      end
      permute(v.to_u32)
      nil
    end

    # Mix slice of bytes to state (for string hashing)
    def <<(b : Bytes) : Nil
      permute(b)
      nil
    end

    # Mix any value to state. `value` should implement `hash(hasher)` method.
    #
    # Numbers implement this method in a way equal numbers are hashed
    # to same hashsum.
    def <<(value) : Nil
      cp = value.hash(self)
      @a = cp.a
      nil
    end

    # Returns hashsum for current state.
    # It doesn't mutate hasher itself.
    def digest : Value
      a = @a
      a ^= a >> 17
      a *= 0xb8b34b2d_u32
      a ^= a >> 16
      a
    end

    # String representaion.
    #
    # It is overloaded to protect against occasional output.
    # `inspect` is not overloaded, though.
    def to_s(io : IO)
      io << "Hash::Hasher()"
    end

    protected def permute_nil
      # LFSR
      mx = (@a.to_i32 >> 31).to_u32 & 0xa8888eef_u32
      @a = (@a << 1) ^ mx
    end

    protected def permute(v : UInt8)
      @a = @a * 31 + v
    end

    protected def permute(v : UInt32)
      @a = @a * 31 + v
    end

    protected def permute(buf : Bytes)
      buf.each do |b|
        @a = @a * 31 + b
      end
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
end
