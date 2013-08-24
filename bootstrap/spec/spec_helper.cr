require "spec"
require "../crystal/**"

include Crystal

def assert_type(str)
  input = Parser.parse str
  mod = infer_type input
  expected_type = mod.yield
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
end

def parse(string)
  Parser.parse string
end
