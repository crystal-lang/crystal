require "json"
require "big"

def BigInt.new(pull : JSON::PullParser)
  pull.read_int
  BigInt.new(pull.raw_value)
end

def BigFloat.new(pull : JSON::PullParser)
  pull.read_float
  BigFloat.new(pull.raw_value)
end
