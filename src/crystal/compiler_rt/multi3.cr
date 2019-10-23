require "./i128_info"
require "./mulddi3"

# Functions for returning the product of signed integer multiplication eg. `a * b`

fun __multi3(a : Int128, b : Int128) : Int128
  x = a.unsafe_as(CompilerRT::I128)
  y = b.unsafe_as(CompilerRT::I128)
  r = CompilerRT::I128.new

  r.all = __mulddi3(x.info.low, y.info.low)
  r.info.high += x.info.high &* y.info.low &+ x.info.low &* y.info.high

  r.all
end

