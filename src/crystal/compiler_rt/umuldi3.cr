# Functions for returning the product of unsigned integer multiplication eg. `a * b`

fun __umuldi3(a : UInt64, b : UInt64) : UInt128
  r = CompilerRT::UI128.new
  bits_in_dword_2 = (sizeof(Int64) &* 8) // 2
  lower_mask = ~0_u64 >> bits_in_dword_2
  r.info.low = (a & lower_mask) &* (b & lower_mask)
  t = (r.info.low >> bits_in_dword_2).unsafe_as(UInt64)
  r.info.low &= lower_mask
  t = t &+ (a >> bits_in_dword_2) &* (b & lower_mask)
  r.info.low = r.info.low &+ (t & lower_mask) << bits_in_dword_2
  r.info.high = t >> bits_in_dword_2
  t = r.info.low >> bits_in_dword_2
  r.info.low &= lower_mask
  t = t &+ (b >> bits_in_dword_2) &* (a & lower_mask)
  r.info.low = r.info.low &+ (t & lower_mask) << bits_in_dword_2
  r.info.high = r.info.high &+ t >> bits_in_dword_2
  r.info.high = r.info.high &+ (a >> bits_in_dword_2) &* (b >> bits_in_dword_2)
  r.all
end

