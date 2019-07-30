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

puts "#{x} * #{y} = #{x * y}"
p multi3(x, y)

# puts 1111111111_i128 * 10000000000_i128

