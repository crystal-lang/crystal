require "yaml"
require "big"

def BigInt.new(pull : YAML::PullParser)
  BigInt.new(pull.read_scalar)
end

def BigFloat.new(pull : YAML::PullParser)
  BigFloat.new(pull.read_scalar)
end
