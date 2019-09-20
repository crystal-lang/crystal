
# Function return the remainder of the unsigned division eg. `a % b`
fun __umodti3(a : Int128, b : Int128) : Int128
  r = 0_u128
  udivmodti4(a, b, pointerof(r))
  return r
end
