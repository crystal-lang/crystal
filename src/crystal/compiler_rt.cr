# Low Level Runtime Functions for LLVM.
# The function definitions and explinations can be found here.
# https://gcc.gnu.org/onlinedocs/gccint/Libgcc.html#Libgcc

{% skip_file if flag?(:skip_crystal_compiler_rt) %}

require "./compiler_rt/mulodi4.cr"

struct Int128Info
  property low : UInt64 = 0_u64, high : Int64 = 0_i64
  def initialize; end
end

struct UInt128Info
  property low : UInt64 = 0_u64, high : UInt64 = 0_i64
  def initialize; end
end

# Integer Runtime Routines

# Arithmetic Routines
# These are used on platforms that don’t provide hardware support for arithmetic operations.

# Functions for arithmetically shifting bits left eg. `a << b`
# fun __ashlhi3(a : Int16, b : Int32) : Int16
# fun __ashlsi3(a : Int32, b : Int32) : Int32
# fun __ashldi3(a : Int64, b : Int32) : Int64
# fun __ashlti3(a : Int128, b : Int32) : Int128
#   raise "__ashlti3"
# end

# Functions for arithmetically shifting bits right eg. `a >> b`
# fun __ashrhi3(a : Int16, b : Int32) : Int16
# fun __ashrsi3(a : Int32, b : Int32) : Int32
# fun __ashrdi3(a : Int64, b : Int32) : Int64
# fun __ashrti3(a : Int128, b : Int32) : Int128
#   raise "__ashrti3"
# end

# Function for logically shifting left (signed shift)
# fun __lshrhi3(a : Int16, b : Int32) : Int16
# fun __lshrsi3(a : Int32, b : Int32) : Int32
# fun __lshrdi3(a : Int64, b : Int32) : Int64
# fun __lshrti3(a : Int128, b : Int32) : Int128
#   raise "__lshrti3"
# end

# Functions for returning the product eg. `a * b`
# fun __mulqi3(a : Int8, b : Int8) : Int8
# fun __mulhi3(a : Int16, b : Int16) : Int16
# fun __mulsi3(a : Int32, b : Int32) : Int32
# fun __muldi3(a : Int64, b : Int64) : Int64

def __umuldi3(a : UInt64, b : UInt64) : UInt128
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

def __multi3(a : Int128, b : Int128) : Int128
  x = a.unsafe_as(Int128Info)
  y = b.unsafe_as(Int128Info)

  r = umuldi3(x.low, y.low).unsafe_as(Int128Info)
  r.high += (x.high * y.low + x.low * y.high).unsafe_as(Int64)

  r.unsafe_as(Int128)
end

fun __muloti4(a : Int128, b : Int128, overflow : Int32*) : Int128
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

# Function returning quotient for signed division eg `a / b`
# fun __divqi3(a : Int8, b : Int8) : Int8
# fun __divhi3(a : Int16, b : Int16) : Int16
# fun __divsi3(a : Int32, b : Int32) : Int32
# fun __divdi3(a : Int64, b : Int64) : Int64
fun __divti3(a : Int128, b : Int128) : Int128
  bits_in_tword_m1 = sizeof(Int128) * sizeof(Char) - 1
  s_a = a >> bits_in_tword_m1                           # s_a = a < 0 ? -1 : 0
  s_b = b >> bits_in_tword_m1                           # s_b = b < 0 ? -1 : 0
  a = (a ^ s_a) - s_a                                   # negate if s_a == -1
  b = (b ^ s_b) - s_b                                   # negate if s_b == -1
  s_a ^= s_b                                            # sign of quotient
  return __udivmodti4(a, b, (0_i128 ^ s_a)) - s_a         # negate if s_a == -1
end

# Function returning quotient for unsigned division eg. `a / b`
# fun __udivqi3(a : UInt8, b : UInt8) : UInt8
# fun __udivhi3(a : UInt16, b : UInt16) : UInt16
# fun __udivsi3(a : UInt32, b : UInt32) : UInt32
# fun __udivdi3(a : UInt64, b : UInt64) : UInt64
fun __udivti3(a : UInt128, b : UInt128) : UInt128
  raise "__udivti3"
end

# Function return the remainder of the signed division eg. `a % b`
# fun __modqi3(a : Int8, b : Int8) : Int8
# fun __modhi3(a : Int16, b : Int16) : Int16
# fun __modsi3(a : Int32, b : Int32) : Int32
# fun __moddi3(a : Int64, b : Int64) : Int64
fun __modti3(a : Int128, b : Int128) : Int128
  bits_in_tword_m1 = sizeof(Int128) * sizeof(Char) - 1
  s = b >> bits_in_tword_m1            # s = b < 0 ? -1 : 0
  b = (b ^ s) - s                      # negate if s == -1
  s = a >> bits_in_tword_m1            # s = a < 0 ? -1 : 0
  a = (a ^ s) - s                      # negate if s == -1
  r = 0_u128
  udivmodti4(a.unsafe_as(UInt128), b.unsafe_as(UInt128), pointerof(r))
  return (r ^ s).unsafe_as(Int128) - s # negate if s == -1
end

# Function return the remainder of the unsigned division eg. `a % b`
# fun __umodqi3(a : Int8, b : Int8) : Int8
# fun __umodhi3(a : Int16, b : Int16) : Int16
# fun __umodsi3(a : Int32, b : Int32) : Int32
# fun __umoddi3(a : Int64, b : Int64) : Int64
fun __umodti3(a : Int128, b : Int128) : Int128
  r = 0_u128
  udivmodti4(a, b, pointerof(r))
  return r
end

fun __udivmodti4(a : UInt128, b : UInt128, rem : UInt128*)
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



# TODO
# __absvti2
# __addvti3
# __negti2
# __negvti2
# __subvti3

# __ashlti3
# __ashrti3
# __lshrti3

# __cmpti2
# __ucmpti2

# __clrsbti2
# __clzti2
# __ctzti2
# __ffsti2

# __divti3
# __modti3
# __multi3
# __mulvti3
# __udivti3
# __umodti3

# __parityti2
# __popcountti2
