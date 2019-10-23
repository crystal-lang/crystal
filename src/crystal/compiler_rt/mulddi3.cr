require "./i128_info"

# Functions for returning the product of signed integer multiplication eg. `a * b`

fun  __mulddi3(a : UInt64, b : UInt64) : Int128
  r = CompilerRT::I128.new
  bits_in_dword_2 = sizeof(Int64) * sizeof(Char) // 2
  lower_mask = ~0.unsafe_as(UInt32) >> bits_in_dword_2

  r.info.low = (a & lower_mask) * (b & lower_mask)
  t = r.info.low >> bits_in_dword_2
  r.info.low &= lower_mask
  t += (a >> bits_in_dword_2) * (b & lower_mask)
  r.info.low += (t & lower_mask) << bits_in_dword_2
  r.info.high = t >> bits_in_dword_2
  t = r.info.low >> bits_in_dword_2
  r.info.low &= lower_mask
  t += (b >> bits_in_dword_2) * (a & lower_mask)
  r.info.low += (t & lower_mask) << bits_in_dword_2
  r.info.high += t >> bits_in_dword_2
  r.info.high += (a >> bits_in_dword_2) * (b >> bits_in_dword_2)

  r.all
end

