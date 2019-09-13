## TODO: case off IO::ByteFormat::SystemEndian for struct order
struct Int128Info
  property low : UInt64 = 0_u64, high : Int64 = 0_i64
  def initialize; end
end

struct UInt128Info
  property low : UInt64 = 0_u64, high : UInt64 = 0_i64
  def initialize; end
end

def umuldi3(a : UInt64, b : UInt64) : UInt128
  r = UInt128Info.new
  bits_in_dword_2 = (sizeof(Int64) * 8) / 2
  lower_mask = ~0_u64 >> bits_in_dword_2
  r.low = (a & lower_mask) * (b & lower_mask)
  t = (r.low >> bits_in_dword_2).unsafe_as(UInt64)
  r.low &= lower_mask
  t += (a >> bits_in_dword_2) * (b & lower_mask)
  r.low += (t & lower_mask) << bits_in_dword_2
  r.high = t >> bits_in_dword_2
  t = r.low >> bits_in_dword_2
  r.low &= lower_mask
  t += (b >> bits_in_dword_2) * (a & lower_mask)
  r.low += (t & lower_mask) << bits_in_dword_2
  r.high += t >> bits_in_dword_2
  r.high += (a >> bits_in_dword_2) * (b >> bits_in_dword_2)
  r.unsafe_as(UInt128)
end

def multi3(a : Int128, b : Int128) : Int128
  x = a.unsafe_as(Int128Info)
  y = b.unsafe_as(Int128Info)

  r = umuldi3(x.low, y.low).unsafe_as(Int128Info)
  r.high += (x.high * y.low + x.low * y.high).unsafe_as(Int64)

  r.unsafe_as(Int128)
end

# x = Int128::MAX - Int32::MAX
# y = 1000_i128
x = 1111111111_i128
y = 10000000000_i128

puts "#{x}:#{x.class}"
puts "#{y}:#{y.class}"
puts "#{(x * y)}:#{(x * y).class}"
puts "#{x} * #{y} = #{x * y}"
puts "#{x} * #{y} = #{multi3(x, y)}"
puts "", ""

fun muloti4(a : Int128, b : Int128, overflow : Int32*) : Int128
  n = 64
  min = Int64::MIN
  max = Int64::MAX
  overflow.value = 0
  result = a &* b
  if a == min
    if b != 0 && b != 1
      overflow.value = 1
    end
    return result
  end
  if b == min
    if a != 0 && a != 1
      overflow.value = 1
    end
    return result
  end
  sa = a >> (n &- 1)
  abs_a = (a ^ sa) &- sa
  sb = b >> (n &- 1)
  abs_b = (b ^ sb) &- sb
  if abs_a < 2 || abs_b < 2
    return result
  end
  if sa == sb
    if abs_a > max // abs_b
      overflow.value = 1
    end
  else
    if abs_a > min // (0i64 &- abs_b)
      overflow.value = 1
    end
  end
  return result
end


x = Int128::MAX
y = 2_i128

puts "#{x}:#{x.class}"
puts "#{y}:#{y.class}"
begin
  x * y
rescue OverflowError
  puts "x * y:raises"
end

puts "#{x} * #{y} raises true"

o = 0
muloti4(x, y, pointerof(o));
puts "#{x} * #{y} raises #{o == 0 ? false : true}"

def udivmodti4(a : UInt128, b : UInt128, rem : UInt128*)
  n_udword_bits = sizeof(Int64) * sizeof(Char);
  n_utword_bits = sizeof(Int128) * sizeof(Char);
  n = a.unsafe_as(UInt128Info)
  d = b.unsafe_as(UInt128Info)
  q = UInt128Info.new
  r = UInt128Info.new
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
    r.high = (r.high << 1) | (r.low  >> (n_udword_bits - 1))
    r.low  = (r.low  << 1) | (q.high >> (n_udword_bits - 1))
    q.high = (q.high << 1) | (q.low  >> (n_udword_bits - 1))
    q.low  = (q.low  << 1) | carry
    s = (d.unsafe_as(UInt128) - r.unsafe_as(UInt128) - 1) >> (n_utword_bits - 1)
    carry = s & 1
    r = (r.unsafe_as(UInt128) - (d.unsafe_as(UInt128) & s)).unsafe_as(UInt128Info)
  end

  q = ((q.unsafe_as(UInt128) << 1) | carry).unsafe_as(UInt128Info)
  if rem
    rem.value = r.unsafe_as(UInt128)
  end
  return q.unsafe_as(UInt128)
end

x = 100_u128
y = 2_u128
rem = 0_u128
results = udivmodti4(x, y, pointerof(rem))
puts "divide with remainder"
puts "#{x} / #{y} = #{results} & #{rem}"
x = UInt128::MAX
y = 1000_u128
rem = 0_u128
results = udivmodti4(x, y, pointerof(rem))
puts "#{x} / #{y} = #{results} & #{rem}"

def divti3(a : Int128, b : Int128) : Int128
  bits_in_tword_m1 = sizeof(Int128) * sizeof(Char) - 1
  s_a = a >> bits_in_tword_m1                           # s_a = a < 0 ? -1 : 0
  s_b = b >> bits_in_tword_m1                           # s_b = b < 0 ? -1 : 0
  a = (a ^ s_a) - s_a                                   # negate if s_a == -1
  b = (b ^ s_b) - s_b                                   # negate if s_b == -1
  s_a ^= s_b                                            # sign of quotient
  return udivmodti4(a, b, (0_i128 ^ s_a)) - s_a         # negate if s_a == -1
end

# puts "#{Int64::MAX} * #{2_u64} = #{Int64::MAX * 2_u64}"
# puts "#{Int64::MAX} &* #{2_u64} = #{Int64::MAX &* 2_u64}"

#puts "size #{sizeof(Int128)} / #{sizeof(LibC::ULongLong)}"
#x = 100_i128
#y = 2_i128
#puts "#{x} / #{y} = #{x / y}"

