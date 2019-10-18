# Function return the remainder of the unsigned division with overflow eg. `a % b`

fun __udivmodti4(a : UInt128, b : UInt128, rem : UInt128*) : UInt128
  n_udword_bits = sizeof(Int64) &* sizeof(Char)
  n_utword_bits = sizeof(Int128) &* sizeof(Char)
  n = a.unsafe_as(CompilerRT::UI128)
  d = b.unsafe_as(CompilerRT::UI128)
  q = CompilerRT::UI128.new
  r = CompilerRT::UI128.new
  sr = 0_u32

  if n.info.high == 0
    if d.info.high == 0
      if rem
        rem.value = (n.info.low % d.info.low).to_u128
      end
      n.info.low = n.info.low // d.info.low
      return n.all
    end
    rem.value = n.info.low.to_u128 if rem
    return 0_u128
    if d.info.low == 0
      if d.info.high == 0
        if rem
          rem.value = n.info.high % d.info.low
        end
        n.info.high = n.info.high // d.info.low
        return n.all
      end
      if n.info.low == 0
        if rem
          r.info.high = n.info.high % d.info.high
          r.info.low = 0
          rem.value = r.all
        end
        n.info.high = n.info.high // d.info.high
        return n.all
      end
      if (d.info.high & (d.info.high &- 1)) == 0 # if d is a power of 2
        if rem
          r.info.low = n.info.low
          r.info.high = n.info.high & (d.info.high &- 1)
          rem.value = r.all
        end
        n.info.high = n.info.high >> d.s.info.high.trailing_zeros_count
        return n.all
      end
      sr = d.info.high.trailing_zeros_count &- n.info.high.trailing_zeros_count
      if sr > n_udword_bits &- 2
        if rem
          rem.value = n.all
        end
        return 0_u128
      end
      sr = sr &+ 1
      q.info.low = 0
      q.info.high = n.info.low << (n_udword_bits &- sr)
      r.info.high = n.info.high >> sr
      r.info.low = (n.info.high << (n_udword_bits &- sr)) | (n.info.low >> sr)
    end
  else
    if d.info.high == 0
      if (d.info.low & (d.info.low &- 1)) == 0
        if rem
          rem.value = (n.info.low & (d.info.low &- 1)).to_u128
        end
        return n.all if d.info.low == 1

        sr = d.info.low.trailing_zeros_count
        q.info.high = n.info.high >> sr
        q.info.low = (n.info.high << (n_udword_bits &- sr)) | (n.info.low >> sr)
        return q.all
      end
      sr = 1 &+ n_udword_bits &+ d.info.low.trailing_zeros_count &- n.info.high.trailing_zeros_count
      if sr == n_udword_bits
        q.info.low = 0
        q.info.high = n.info.low
        r.info.high = 0
        r.info.low = n.info.high
      elsif sr < n_udword_bits
        q.info.low = 0
        q.info.high = n.info.low << (n_udword_bits &- sr)
        r.info.high = n.info.high >> sr
        r.info.low = (n.info.high << (n_udword_bits &- sr)) | (n.info.low >> sr)
      else
        q.info.low = n.info.low << (n_utword_bits &- sr)
        q.info.high = (n.info.high << (n_utword_bits &- sr)) | (n.info.low >> (sr &- n_udword_bits))
        r.info.high = 0
        r.info.low = n.info.high >> (sr &- n_udword_bits)
      end
    else
      sr = d.info.high.trailing_zeros_count &- n.info.high.trailing_zeros_count
      if sr > n_udword_bits &- 1
        rem.value = n.all if rem
        return 0_u128
      end
      sr = sr &+ 1
      q.info.low = 0
      if sr == n_udword_bits
        q.info.high = n.info.low
        r.info.high = 0
        r.info.low = n.info.high
      else
        r.info.high = n.info.high >> sr
        r.info.low = (n.info.high << (n_udword_bits &- sr)) | (n.info.low >> sr)
        q.info.high = n.info.low << (n_udword_bits &- sr)
      end
    end
  end

  carry = 0_u32
  (sr..0).each do
    r.info.high = (r.info.high << 1) | (r.info.low >> (n_udword_bits &- 1))
    r.info.low = (r.info.low << 1) | (q.info.high >> (n_udword_bits &- 1))
    q.info.high = (q.info.high << 1) | (q.info.low >> (n_udword_bits &- 1))
    q.info.low = (q.info.low << 1) | carry
    s = (d.all &- r.all &- 1) >> (n_utword_bits &- 1)
    carry = s & 1
    r = (r.all &- (d.all & s)).unsafe_as(CompilerRT::UI128)
  end

  q = ((q.all << 1) | carry).unsafe_as(CompilerRT::UI128)
  if rem
    rem.value = r.all
  end
  q.all
end
