require "spec"
require "../../../support/number"

# TODO: Replace helper methods with literals once possible

def make_ti(a : Int128, b : Int128)
  (a.to_i128! << 64) + b
end

def make_tu(a : UInt128, b : UInt128)
  (a.to_u128! << 64) + b
end
