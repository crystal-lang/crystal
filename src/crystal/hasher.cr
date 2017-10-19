require "random/secure"

# :nodoc:
struct Crystal::Hasher
  # Implementation of a Hasher to compute a fast and safe hash
  # value for primitive and basic Crystal objects. All other
  # hashes are computed based on these.
  #
  # TODO: the implementation is naive and should probably use
  # another algorithm like SipHash or FNV.

  @@seed = uninitialized UInt64[2]
  Random::Secure.random_bytes(Slice.new(pointerof(@@seed).as(UInt8*), sizeof(typeof(@@seed))))

  @a : UInt64 = @@seed[0]
  @b : UInt64 = @@seed[1]

  private C1 = 0xacd5ad43274593b9_u64
  private C2 = 0x6956abd6ed268a3d_u64

  private def rotl32(v : UInt64)
    v.unsafe_shl(32) | v.unsafe_shr(32)
  end

  private def permute(v : UInt64)
    @a = rotl32(@a ^ v) * C1
    @b = (rotl32(@b) ^ v) * C2
    self
  end

  def result
    a, b = @a, @b
    a ^= a >> 33
    b ^= b >> 32
    a *= C1
    b *= C2
    a ^= a >> 32
    b ^= b >> 33
    a + b
  end

  def nil
    self
  end

  def bool(value)
    (value ? 1 : 0).hash(self)
  end

  def int(value)
    permute(value.to_u64)
  end

  def float(value)
    permute(value.to_f64.unsafe_as(UInt64))
  end

  def char(value)
    value.ord.hash(self)
  end

  def enum(value)
    value.value.hash(self)
  end

  def symbol(value)
    value.to_i.hash(self)
  end

  def reference(value)
    permute(value.object_id.to_u64)
  end

  def string(value)
    string(value.to_slice)
  end

  @[NoInline]
  def string(value : Bytes)
    bsz = value.size
    v = bsz.to_u64 << 56
    u = value.to_unsafe
    bsz.unsafe_div(8).downto(1) do
      # force correct unaligned read
      t8 = uninitialized UInt64
      pointerof(t8).as(UInt8*).copy_from(u, 8)
      permute(t8)
      u += 8
    end
    if (bsz & 4) != 0
      # force correct unaligned read
      t4 = uninitialized UInt32
      pointerof(t4).as(UInt8*).copy_from(u, 4)
      v |= t4 << 24
      u += 4
    end
    if (r = bsz & 3) != 0
      v |= u[0].to_u64 | (u[r/2].to_u64 << 8) | (u[r - 1].to_u64 << 16)
    end
    permute(v)
    self
  end

  def class(value)
    value.crystal_type_id.hash(self)
  end
end
