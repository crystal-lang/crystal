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

def BigDecimal.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    pull.read_int
    value = pull.raw_value
  when :float
    pull.read_float
    value = pull.raw_value
  else
    value = pull.read_string
  end
  BigDecimal.new(value)
end
