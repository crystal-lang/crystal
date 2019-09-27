# Function return the remainder of the unsigned division eg. `a % b`
fun __umodti3(a : UInt128, b : UInt128) : UInt128
  r = 0_u128
  __udivmodti4(a, b, pointerof(r))
  r
end
