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

record InferTypeResult,
  program : Program,
  node : ASTNode,
  type : Type

def assert_type(str, flags = nil)
  result = infer_type_result(str, flags)
  program = result.program
  expected_type = with program yield program
  result.type.should eq(expected_type)
  result
end

def infer_type(code : String, wants_doc = false)
  infer_type parse(code, wants_doc: wants_doc), wants_doc: wants_doc
end

def infer_type(node : ASTNode, wants_doc = false)
  program = Program.new
  program.wants_doc = wants_doc
  node = program.normalize node
  node = program.infer_type node
  InferTypeResult.new(program, node, node.type)
end

def infer_type_result(str, flags = nil)
  program = Program.new
  program.flags = flags if flags
  input = parse str
  input = program.normalize input
  input = program.infer_type input
  input_type = input.is_a?(Expressions) ? input.last.type : input.type
  InferTypeResult.new(program, input, input_type)
end

def assert_normalize(from, to, flags = nil)
  program = Program.new
  program.flags = flags if flags
  normalizer = Normalizer.new(program)
  from_nodes = Parser.parse(from)
  to_nodes = normalizer.normalize(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def assert_expand(from : String, to)
  assert_expand Parser.parse(from), to
end

def assert_expand(from_nodes : ASTNode, to)
  to_nodes = LiteralExpander.new(Program.new).expand(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def assert_expand_second(from : String, to)
  node = (Parser.parse(from) as Expressions)[1]
  assert_expand node, to
end

def assert_after_cleanup(before, after)
  node = Parser.parse(before)
  result = infer_type node
  result.node.to_s.strip.should eq(after.strip)
end

def assert_syntax_error(str, message = nil, line = nil, column = nil, metafile = __FILE__, metaline = __LINE__)
  it "says syntax error on #{str.inspect}", metafile, metaline do
    begin
      parse str
      fail "expected SyntaxException to be raised", metafile, metaline
    rescue ex : SyntaxException
      ex.message.not_nil!.includes?(message.not_nil!).should be_true, metafile, metaline if message
      ex.line_number.should eq(line.not_nil!), metafile, metaline if line
      ex.column_number.should eq(column.not_nil!), metafile, metaline if column
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
  program = Program.new
  sub_node = yield program
  assert_macro_internal program, sub_node, macro_args, macro_body, expected
end

def assert_macro_internal(program, sub_node, macro_args, macro_body, expected)
  macro_def = "macro foo(#{macro_args});#{macro_body};end"
  a_macro = Parser.parse(macro_def) as Macro

  call = Call.new(nil, "", sub_node)
  result = program.expand_macro a_macro, call, program
  result = result.source
  result = result[0..-2] if result.ends_with?(';')
  result.should eq(expected)
end

def parse(string, wants_doc = false)
  parser = Parser.new(string)
  parser.wants_doc = wants_doc
  parser.parse
end

def codegen(code)
  node = parse code
  result = infer_type node
  result.program.codegen result.node, single_module: false
end

class Crystal::SpecRunOutput
  @output : String

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

def run(code, filename = nil)
  # Code that requires the prelude doesn't run in LLVM's MCJIT
  # because of missing linked functions (which are available
  # in the current executable!), so instead we compile
  # the program and run it, printing the last
  # expression and using that to compare the result.
  if code.includes?(%(require "prelude"))
    ast = Parser.parse(code) as Expressions
    last = ast.expressions.last
    assign = Assign.new(Var.new("__tempvar"), last)
    call = Call.new(nil, "print", Var.new("__tempvar"))
    exps = Expressions.new([assign, call] of ASTNode)
    ast.expressions[-1] = exps
    code = ast.to_s

    output_filename = Crystal.tempfile("crystal-spec-output")

    compiler = Compiler.new
    compiler.compile Compiler::Source.new("spec", code), output_filename

    output = `#{output_filename}`
    File.delete(output_filename)

    SpecRunOutput.new(output)
  else
    Program.new.run(code, filename: filename)
  end
end

def test_c(c_code, crystal_code)
  c_filename = "#{__DIR__}/temp_abi.c"
  o_filename = "#{__DIR__}/temp_abi.o"
  begin
    File.write(c_filename, c_code)

    `#{Crystal::Compiler::CC} #{c_filename} -c -o #{o_filename}`.should be_truthy

    yield run(%(
    require "prelude"

    @[Link(ldflags: "#{o_filename}")]
    #{crystal_code}
    ))
  ensure
    File.delete(c_filename)
    File.delete(o_filename)
  end
end
