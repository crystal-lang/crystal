require "./i128_info"
require "./mulddi3"

# Functions for returning the product of signed integer multiplication eg. `a * b`

fun __multi3(a : Int128, b : Int128) : Int128
  x = Int128RT.new
  x.all = a
  y = Int128RT.new
  y.all = b
  r = Int128RT.new

  r.all = __mulddi3(x.info.low, y.info.low)
  r.info.high = r.info.high &+ x.info.high &* y.info.low &+ x.info.low &* y.info.high

  r.all
end

