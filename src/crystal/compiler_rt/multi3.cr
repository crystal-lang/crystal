# Functions for returning the product of signed integer multiplication eg. `a * b`
fun __multi3(a : Int128, b : Int128) : Int128
  x = a.unsafe_as(CompilerRT::I128Info)
  y = b.unsafe_as(CompilerRT::I128Info)

  r = __umuldi3(x.low, y.low).unsafe_as(CompilerRT::I128Info)
  r.high += (x.high * y.low + x.low * y.high).unsafe_as(Int64)

  r.unsafe_as(Int128)
end
