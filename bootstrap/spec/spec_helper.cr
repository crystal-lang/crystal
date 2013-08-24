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

def assert_normalize(from, to)
  program = Program.new
  normalizer = Normalizer.new(program)
  from_nodes = Parser.parse(from)
  to_nodes = normalizer.normalize(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def parse(string)
  Parser.parse string
end
