## TODO: case off IO::ByteFormat::SystemEndian for struct order
struct Int128Info
  property low : UInt64 = 0_u64, high : UInt64 = 0_i64
  def initialize; end
end

def umuldi3(a : UInt64, b : UInt64) : UInt128
  r = Int128Info.new
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

  # p x, y, r.unsafe_as(Int128Info)
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

# puts "#{Int64::MAX} * #{2_u64} = #{Int64::MAX * 2_u64}"
# puts "#{Int64::MAX} &* #{2_u64} = #{Int64::MAX &* 2_u64}"
