require "spec"
require "../crystal/**"

include Crystal

class InferTypeResult
  getter :program
  getter :node

  def initialize(@program, @node)
  end
end

def assert_type(str)
  program = Program.new
  input = parse str
  input = program.infer_type input
  expected_type = program.yield(program)
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
end

def infer_type(node)
  program = Program.new
  node = program.normalize node
  node = program.infer_type node
  InferTypeResult.new(program, node)
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

def run(code)
  Program.new.run(code)
end
