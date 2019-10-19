require "./udivmodti4"

# Function returning quotient for signed division eg `a / b`

fun __divti3(a : Int128, b : Int128) : Int128
  bits_in_tword_m1 = sizeof(Int128) &* sizeof(Char) &- 1
  s_a = a >> bits_in_tword_m1
  s_b = b >> bits_in_tword_m1
  a = (a ^ s_a) &- s_a
  b = (b ^ s_b) &- s_b
  s_a ^= s_b
  r = (0_i128 ^ s_a).unsafe_as(UInt128)
  (__udivmodti4(a.unsafe_as(UInt128), b.unsafe_as(UInt128), pointerof(r)) &- s_a).unsafe_as(Int128)
end
