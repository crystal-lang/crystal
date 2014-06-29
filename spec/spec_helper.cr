ENV["CRYSTAL_PATH"] = "#{__DIR__}/../src"
ENV["VERIFY"] = "1"

require "spec"
require "../src/compiler/crystal/**"

include Crystal

class Crystal::Program
  def union_of(type1, type2)
    union_of([type1, type2] of Type).not_nil!
  end

  def union_of(type1, type2, type3)
    union_of([type1, type2, type3] of Type).not_nil!
  end

  def fun_of(type1 : Type)
    fun_of([type1] of Type)
  end

  def fun_of(type1 : Type, type2 : Type)
    fun_of([type1, type2] of Type)
  end
end

make_named_tuple InferTypeResult, [program, node]

def assert_type(str)
  program = Program.new
  input = parse str
  input = program.normalize input
  input = program.infer_type input
  expected_type = with program yield program
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
  InferTypeResult.new(program, input)
end

def infer_type(node)
  program = Program.new
  node = program.normalize node
  node = program.infer_type node
  InferTypeResult.new(program, node)
end

def assert_normalize(from, to, flags = nil)
  program = Program.new
  program.flags = flags if flags
  normalizer = Normalizer.new(program)
  from_nodes = Parser.parse(from)
  to_nodes = normalizer.normalize(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def assert_expand(from, to)
  from_nodes = Parser.parse(from)
  to_nodes = LiteralExpander.new(Program.new).expand(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def assert_after_type_inference(before, after)
  node = Parser.parse(before)
  result = infer_type node
  result.node.to_s.strip.should eq(after.strip)
end

def assert_syntax_error(str, message)
  begin
    parse str
    fail "SyntaxException wasn't raised"
  rescue ex : Crystal::SyntaxException
    fail "Expected '#{ex}' to contain '#{message}'" unless ex.to_s.includes? message
  end
end

def assert_error(str, message)
  nodes = parse str
  begin
    infer_type nodes
    fail "TypeException wasn't raised"
  rescue ex : Crystal::TypeException
    fail "Expected '#{ex}' to contain '#{message}'" unless ex.to_s.includes? message
  end
end

def assert_macro(macro_args, macro_body, call_args, expected)
  macro_def = "macro foo(#{macro_args});#{macro_body};end"
  a_macro = Parser.parse(macro_def) as Macro

  program = Program.new
  call = Call.new(nil, "", call_args)
  result = program.expand_macro program, a_macro, call
  result = result[0 .. -2] if result.ends_with?(';')
  result.should eq(expected)
end

def parse(string)
  Parser.parse string
end

def build(code)
  node = parse code
  result = infer_type node
  result.program.build result.node, Program::BuildOptions.single_module
end

def run(code)
  Program.new.run(code)
end
