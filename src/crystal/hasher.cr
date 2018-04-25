require "random/secure"

# :nodoc:
struct Crystal::Hasher
  # Implementation of a Hasher to compute a fast and safe hash
  # value for primitive and basic Crystal objects. All other
  # hashes are computed based on these.
  #
  # The algorithm bases on https://github.com/funny-falcon/funny_hash
  #
  # It is two multiply-rotate 64bit hash functions, combined
  # within finalizer.
  #
  # Both hash functions combines previous state with a block value
  # before multiplication. One function multiplies new state
  # as is (and then rotates state), other multiplies new state
  # already rotated by 32 bits.
  #
  # This way algorithm ensures that every block bit affects at
  # least 1 bit of every state, and certainly many bits of some
  # state. So effect of this bit could not be easily canceled
  # with following blocks. (Cause next blocks have to cancel
  # bits on non-intersecting positions in both states).
  # Rotation by 32bit with multiplication also provides good
  # inter-block avalanche.
  #
  # Finalizer performs murmur-like finalization on both functions,
  # and then combines them with addition. It greatly reduce
  # possibility of state deduction.
  #
  # Note, it provides good protection from HashDos if and only if:
  # - seed is securely random and not exposed to attacker,
  # - hash result is also not exposed to attacker in a way other
  #   than effect of using it in Hash implementation.
  # Do not output calculated hash value to user's console/form/
  # html/api response, etc. Use some from digest package instead.

  # Based on https://github.com/python/cpython/blob/f051e43/Python/pyhash.c#L34
  #
  # For numeric types, the hash of a number x is based on the reduction
  # of x modulo the Mersen Prime P = 2**HASH_BITS - 1.  It's designed
  # so that hash(x) == hash(y) whenever x and y are numerically equal,
  # even if x and y have different types.
  # A quick summary of the hashing strategy:
  # (1) First define the 'reduction of x modulo P' for any rational
  # number x; this is a standard extension of the usual notion of
  # reduction modulo P for integers.  If x == p/q (written in lowest
  # terms), the reduction is interpreted as the reduction of p times
  # the inverse of the reduction of q, all modulo P; if q is exactly
  # divisible by P then define the reduction to be infinity.  So we've
  # got a well-defined map
  #   reduce : { rational numbers } -> { 0, 1, 2, ..., P-1, infinity }.
  # (2) Now for a rational number x, define hash(x) by:
  #   reduce(x)   if x >= 0
  #   -reduce(-x) if x < 0
  # If the result of the reduction is infinity (this is impossible for
  # integers, floats and Decimals) then use the predefined hash value
  # HASH_INF_PLUS for x >= 0, or HASH_INF_MINUS for x < 0, instead.
  # HASH_INF_PLUS, HASH_INF_MINUS and HASH_NAN are also used for the
  # hashes of float and Decimal infinities and nans.
  # A selling point for the above strategy is that it makes it possible
  # to compute hashes of decimal and binary floating-point numbers
  # efficiently, even if the exponent of the binary or decimal number
  # is large.  The key point is that
  #   reduce(x * y) == reduce(x) * reduce(y) (modulo HASH_MODULUS)
  # provided that {reduce(x), reduce(y)} != {0, infinity}.  The reduction of a
  # binary or decimal float is never infinity, since the denominator is a power
  # of 2 (for binary) or a divisor of a power of 10 (for decimal).  So we have,
  # for nonnegative x,
  #   reduce(x * 2**e) == reduce(x) * reduce(2**e) % HASH_MODULUS
  #   reduce(x * 10**e) == reduce(x) * reduce(10**e) % HASH_MODULUS
  # and reduce(10**e) can be computed efficiently by the usual modular
  # exponentiation algorithm.  For reduce(2**e) it's even better: since
  # P is of the form 2**n-1, reduce(2**e) is 2**(e mod n), and multiplication
  # by 2**(e mod n) modulo 2**n-1 just amounts to a rotation of bits.

  private HASH_BITS    = 61
  private HASH_MODULUS = (1_i64 << HASH_BITS) - 1

  private HASH_NAN       =      0_u64
  private HASH_INF_PLUS  = 314159_u64
  private HASH_INF_MINUS = (-314159_i64).unsafe_as(UInt64)

  @@seed = uninitialized UInt64[2]
  Random::Secure.random_bytes(Slice.new(pointerof(@@seed).as(UInt8*), sizeof(typeof(@@seed))))

  def initialize(@a : UInt64 = @@seed[0], @b : UInt64 = @@seed[1])
  end

  private C1 = 0xacd5ad43274593b9_u64
  private C2 = 0x6956abd6ed268a3d_u64

  private def rotl32(v : UInt64)
    (v << 32) | (v >> 32)
  end

  private def permute(v : UInt64)
    @a = rotl32(@a ^ v) * C1
    @b = (rotl32(@b) ^ v) * C2
    self
  end

  def result
    a, b = @a, @b
    a ^= (a >> 23) ^ (a >> 40)
    b ^= (b >> 23) ^ (b >> 40)
    a *= C1
    b *= C2
    a ^= a >> 32
    b ^= b >> 32
    a + b
  end

  def nil
    @a += @b
    @b += 1
    self
  end

  def bool(value)
    (value ? 1 : 0).hash(self)
  end

  def int(value : Int8 | Int16 | Int32)
    permute(value.to_i64.unsafe_as(UInt64))
  end

  def int(value : UInt8 | UInt16 | UInt32)
    permute(value.to_u64)
  end

  def int(value : Int::Unsigned)
    permute(value.remainder(HASH_MODULUS).to_u64)
  end

  def int(value : Int)
    permute(value.remainder(HASH_MODULUS).to_i64.unsafe_as(UInt64))
  end

  # This function is for reference implementation, and it is used for `BigFloat`.
  # For `Float64` and `Float32` all supported architectures allows more effective
  # bitwise calculation.
  # Arguments `frac` and `exp` are result of equivalent `Math.frexp`, though
  # for `BigFloat` custom calculation used for more precision.
  private def float_normalize_reference(value, frac, exp)
    if value < 0
      frac = -frac
    end
    # process 28 bits at a time;  this should work well both for binary
    # and hexadecimal floating point.
    x = 0_i64
    while frac > 0
      x = ((x << 28) & HASH_MODULUS) | x >> (HASH_BITS - 28)
      frac *= 268435456.0 # 2**28
      exp -= 28
      y = frac.to_u32 # pull out integer part
      frac -= y
      x += y
      x -= HASH_MODULUS if x >= HASH_MODULUS
    end
    {x, exp}
  end

  private def float_normalize_wrap(value)
    return HASH_NAN if value.nan?
    if value.infinite?
      return value > 0 ? HASH_INF_PLUS : HASH_INF_MINUS
    end

    x, exp = yield value

    # adjust for the exponent;  first reduce it modulo HASH_BITS
    exp = exp >= 0 ? exp % HASH_BITS : HASH_BITS - 1 - ((-1 - exp) % HASH_BITS)
    x = ((x << exp) & HASH_MODULUS) | x >> (HASH_BITS - exp)

    (x * (value < 0 ? -1 : 1)).to_i64.unsafe_as(UInt64)
  end

  def float(value : Float32)
    normalized_hash = float_normalize_wrap(value) do |value|
      # This optimized version works on every architecture where endianess
      # of Float32 and Int32 matches and float is IEEE754. All supported
      # architectures fall into this category.
      unsafe_int = value.unsafe_as(Int32)
      exp = (((unsafe_int >> 23) & 0xff) - 127)
      mantissa = unsafe_int & ((1 << 23) - 1)
      if exp > -127
        exp -= 23
        mantissa |= 1 << 23
      else
        # subnormals
        exp -= 22
      end
      {mantissa.to_i64, exp}
    end
    permute(normalized_hash)
  end

  def float(value : Float64)
    normalized_hash = float_normalize_wrap(value) do |value|
      # This optimized version works on every architecture where endianess
      # of Float64 and Int64 matches and float is IEEE754. All supported
      # architectures fall into this category.
      unsafe_int = value.unsafe_as(Int64)
      exp = (((unsafe_int >> 52) & 0x7ff) - 1023)
      mantissa = unsafe_int & ((1_u64 << 52) - 1)
      if exp > -1023
        exp -= 52
        mantissa |= 1_u64 << 52
      else
        # subnormals
        exp -= 51
      end

      {mantissa.to_i64, exp}
    end
    permute(normalized_hash)
  end

  def float(value : Float)
    normalized_hash = float_normalize_wrap(value) do |value|
      frac, exp = Math.frexp value
      float_normalize_reference(value, frac, exp)
    end
    permute(normalized_hash)
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
    bytes(value.to_slice)
  end

  private def read_u24(ptr, rest)
    ptr[0].to_u64 | (ptr[rest/2].to_u64 << 8) | (ptr[rest - 1].to_u64 << 16)
  end

  private def read_u32(ptr)
    # force correct unaligned read
    t4 = uninitialized UInt32
    pointerof(t4).as(UInt8*).copy_from(ptr, 4)
    t4.to_u64
  end

  private def read_u64(ptr)
    # force correct unaligned read
    t8 = uninitialized UInt64
    pointerof(t8).as(UInt8*).copy_from(ptr, 8)
    t8
  end

  def bytes(value : Bytes)
    size = value.size
    ptr = value.to_unsafe
    if size <= 0
      last = 0_u64
    elsif size <= 3
      last = read_u24(ptr, size)
    elsif size <= 7
      last = read_u32(ptr)
      last |= read_u32(ptr + (size & 3)) << 32
    else
      while size >= 8
        permute(read_u64(ptr))
        ptr += 8
        size -= 8
      end
      last = read_u64(ptr - (8 - size))
    end
    @a ^= size
    @b ^= size
    permute(last)
    self
  end

  def class(value)
    value.crystal_type_id.hash(self)
  end

  def inspect(io)
    io << "#{self.class}(hidden_state)"
    nil
  end
end
