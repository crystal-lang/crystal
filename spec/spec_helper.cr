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

  def nilable(type)
    union_of self.nil, type
  end
end

record InferTypeResult, program, node

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

def assert_syntax_error(str)
  it "says syntax error on #{str.inspect}" do
    expect_raises Crystal::SyntaxException do
      parse str
    end
  end
end

def assert_syntax_error(str, message)
  it "says syntax error on #{str.inspect}" do
    expect_raises Crystal::SyntaxException, message do
      parse str
    end
  end
end

def assert_syntax_error(str, message, line, column)
  it "says syntax error on #{str.inspect}" do
    begin
      Parser.parse(str)
      fail "expected SyntaxException to be raised"
    rescue ex : SyntaxException
      ex.message.not_nil!.includes?(message).should be_true
      ex.line_number.should eq(line)
      ex.column_number.should eq(column)
    end
  end
end

def assert_error(str, message)
  nodes = parse str
  expect_raises TypeException, message do
    infer_type nodes
  end
end

def assert_macro(macro_args, macro_body, call_args, expected)
  assert_macro(macro_args, macro_body, expected) { call_args }
end

def assert_macro(macro_args, macro_body, expected)
  macro_def = "macro foo(#{macro_args});#{macro_body};end"
  a_macro = Parser.parse(macro_def) as Macro

  program = Program.new
  call = Call.new(nil, "", yield program)
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
  result.program.build result.node, single_module: true
end

class Crystal::SpecRunOutput
  def initialize(@output)
  end

  def to_string
    @output
  end

  delegate to_i, @output
  delegate to_f, @output
  delegate to_f32, @output
  delegate to_f64, @output

  def to_b
    @output == "true"
  end
end

def run(code)
  # Code that requires the prelude doesn't run in LLVM's MCJIT
  # because of missing linked functions (which are available
  # in the current executable!), so instead we compile
  # the program and run it, printing the last
  # expression and using that to compare the result.
  if code.includes?(%(require "prelude"))
    ast = Parser.parse(code)
    assign = Assign.new(Var.new("__tempvar"), ast)
    call = Call.new(nil, "print!", [Var.new("__tempvar")] of ASTNode)
    code = Expressions.new([assign, call]).to_s

    tempfile = Tempfile.new("crystal-spec-output")
    output_filename = tempfile.path
    tempfile.close

    compiler = Compiler.new
    compiler.output_filename = output_filename
    compiler.compile Compiler::Source.new("spec", code)

    output = `#{output_filename}`
    tempfile.delete

    SpecRunOutput.new(output)
  else
    Program.new.run(code)
  end
end
