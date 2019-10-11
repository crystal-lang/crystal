# Function return the remainder of the signed division eg. `a % b`
fun __modti3(a : Int128, b : Int128) : Int128
  bits_in_tword_m1 = sizeof(Int128) * sizeof(Char) - 1
  s = b >> bits_in_tword_m1 # s = b < 0 ? -1 : 0
  b = (b ^ s) - s           # negate if s == -1
  s = a >> bits_in_tword_m1 # s = a < 0 ? -1 : 0
  a = (a ^ s) - s           # negate if s == -1
  r = 0_u128
  __udivmodti4(a.unsafe_as(UInt128), b.unsafe_as(UInt128), pointerof(r))
  (r ^ s).unsafe_as(Int128) - s # negate if s == -1
end
