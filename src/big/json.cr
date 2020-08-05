require "json"
require "big"

def BigInt.new(pull : JSON::PullParser)
  pull.read_int
  BigInt.new(pull.raw_value)
end

def BigInt.from_json_object_key?(key : String)
  BigInt.new(key)
rescue ArgumentError
  nil
end

def BigFloat.new(pull : JSON::PullParser)
  pull.read_float
  BigFloat.new(pull.raw_value)
end

def BigFloat.from_json_object_key?(key : String)
  BigFloat.new(key)
rescue ArgumentError
  nil
end

def BigDecimal.new(pull : JSON::PullParser)
  case pull.kind
  when .int?
    pull.read_int
    value = pull.raw_value
  when .float?
    pull.read_float
    value = pull.raw_value
  else
    value = pull.read_string
  end
  BigDecimal.new(value)
end

def BigDecimal.from_json_object_key?(key : String)
  BigDecimal.new(key)
rescue InvalidBigDecimalException
  nil
end
