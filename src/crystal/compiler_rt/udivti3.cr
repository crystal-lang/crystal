require "./udivmodti4"

# Functions for returning the product of signed multiplication with overflow eg. `a * b`

fun __udivti3(a : UInt128, b : UInt128) : UInt128
  r = 0_u128
  __udivmodti4(a, b, pointerof(r))
end
