module Number::HashNormalize
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
  # HASH_INF for x >= 0, or -HASH_INF for x < 0, instead.
  # HASH_INF, -HASH_INF and HASH_NAN are also used for the
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

  private HASH_BITS     = 61
  private HASH_MODULUS  = (1_i64 << HASH_BITS) - 1
  private HASH_NAN      =      0_i64
  private HASH_INFINITY = 314159_i64

  private def int_to_hashnorm(v)
    v.to_i64
  end

  # This function is for reference implementation, and it is used for BigFloat.
  # For Float64 and Float32 all supported architectures allows more effective
  # bitwise calculation.
  # Arguments `frac` and `exp` are result of equivalent `Math.frexp`, though
  # for `BigFloat` custom calculation used for more precision.
  private def float_normalize_reference(frac, exp)
    if self < 0
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

  private def float_normalize_wrap
    return HASH_NAN if nan?
    if infinite?
      return self > 0 ? +HASH_INFINITY : -HASH_INFINITY
    end

    x, exp = yield

    # adjust for the exponent;  first reduce it modulo HASH_BITS
    exp = exp >= 0 ? exp % HASH_BITS : HASH_BITS - 1 - ((-1 - exp) % HASH_BITS)
    x = ((x << exp) & HASH_MODULUS) | x >> (HASH_BITS - exp)

    x * (self < 0 ? -1 : 1)
  end
end
