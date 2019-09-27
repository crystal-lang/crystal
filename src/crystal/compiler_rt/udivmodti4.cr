# Function return the remainder of the unsigned division with overflow eg. `a % b`
fun __udivmodti4(a : UInt128, b : UInt128, rem : UInt128*)
  n_udword_bits = sizeof(Int64) * sizeof(Char)
  n_utword_bits = sizeof(Int128) * sizeof(Char)
  n = a.unsafe_as(CompilerRT::U128Info)
  d = b.unsafe_as(CompilerRT::U128Info)
  q = CompilerRT::U128Info.new
  r = CompilerRT::U128Info.new
  sr = 0_u32

  if (n.high == 0)
    if (d.high == 0)
      if rem
        rem.value = (n.low % d.low).to_u128
      end
      return n.low / d.low
    end
    rem.value = n.low.to_u128 if rem
    return 0
    if (d.low == 0)
      if (d.high == 0)
        if rem
          rem.value = n.high % d.low
        end
        return n.high / d.low
      end
      if (n.low == 0)
        if rem
          r.high = n.high % d.high
          r.low = 0
          rem.value = r.unsafe_as(UInt128)
        end
        return n.high / d.high
      end
      if ((d.high & (d.high - 1)) == 0) # if d is a power of 2
        if rem
          r.low = n.low
          r.high = n.high & (d.high - 1)
          rem.value = r.unsafe_as(UInt128)
        end
        return n.high >> d.s.high.trailing_zeros_count
      end
      sr = d.high.trailing_zeros_count - n.high.trailing_zeros_count
      if (sr > n_udword_bits - 2)
        if rem
          rem.value = n.unsafe_as(UInt128)
        end
        return 0
      end
      sr = sr + 1
      q.low = 0
      q.high = n.low << (n_udword_bits - sr)
      r.high = n.high >> sr
      r.low = (n.high << (n_udword_bits - sr)) | (n.low >> sr)
    end
  else
    if (d.high == 0)
      if ((d.low & (d.low - 1)) == 0)
        if rem
          rem.value = (n.low & (d.low - 1)).to_u128
        end
        return n.unsafe_as(UInt128) if d.low == 1

        sr = d.low.trailing_zeros_count
        q.high = n.high >> sr
        q.low = (n.high << (n_udword_bits - sr)) | (n.low >> sr)
        return q.unsafe_as(UInt128)
      end
      sr = 1 + n_udword_bits + d.low.trailing_zeros_count - n.high.trailing_zeros_count
      if (sr == n_udword_bits)
        q.low = 0
        q.high = n.low
        r.high = 0
        r.low = n.high
      elsif (sr < n_udword_bits)
        q.low = 0
        q.high = n.low << (n_udword_bits - sr)
        r.high = n.high >> sr
        r.low = (n.high << (n_udword_bits - sr)) | (n.low >> sr)
      else
        q.low = n.low << (n_utword_bits - sr)
        q.high = (n.high << (n_utword_bits - sr)) | (n.low >> (sr - n_udword_bits))
        r.high = 0
        r.low = n.high >> (sr - n_udword_bits)
      end
    else
      sr = d.high.trailing_zeros_count - n.high.trailing_zeros_count
      if (sr > n_udword_bits - 1)
        rem.value = n.unsafe_as(UInt128) if rem
        return 0
      end
      sr = sr + 1
      q.low = 0
      if (sr == n_udword_bits)
        q.high = n.low
        r.high = 0
        r.low = n.high
      else
        r.high = n.high >> sr
        r.low = (n.high << (n_udword_bits - sr)) | (n.low >> sr)
        q.high = n.low << (n_udword_bits - sr)
      end
    end
  end

  carry = 0_u32
  (sr..0).each do
    r.high = (r.high << 1) | (r.low >> (n_udword_bits - 1))
    r.low = (r.low << 1) | (q.high >> (n_udword_bits - 1))
    q.high = (q.high << 1) | (q.low >> (n_udword_bits - 1))
    q.low = (q.low << 1) | carry
    s = (d.unsafe_as(UInt128) - r.unsafe_as(UInt128) - 1) >> (n_utword_bits - 1)
    carry = s & 1
    r = (r.unsafe_as(UInt128) - (d.unsafe_as(UInt128) & s)).unsafe_as(CompilerRT::U128Info)
  end

  q = ((q.unsafe_as(UInt128) << 1) | carry).unsafe_as(CompilerRT::U128Info)
  if rem
    rem.value = r.unsafe_as(UInt128)
  end
  q.unsafe_as(UInt128)
end
