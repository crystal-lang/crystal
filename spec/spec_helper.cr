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

def assert_type(str, flags = nil)
  program = Program.new
  program.flags = flags if flags
  input = parse str
  input = program.normalize input
  input = program.infer_type input
  expected_type = with program yield program
  if input.is_a?(Expressions)
    expect(input.last.type).to eq(expected_type)
  else
    expect(input.type).to eq(expected_type)
  end
  InferTypeResult.new(program, input)
end

def infer_type(code : String, wants_doc = false)
  infer_type parse(code, wants_doc: wants_doc), wants_doc: wants_doc
end

def infer_type(node : ASTNode, wants_doc = false)
  program = Program.new
  program.wants_doc = wants_doc
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
  expect(to_nodes.to_s.strip).to eq(to.strip)
end

def assert_expand(from, to)
  from_nodes = Parser.parse(from)
  to_nodes = LiteralExpander.new(Program.new).expand(from_nodes)
  expect(to_nodes.to_s.strip).to eq(to.strip)
end

def assert_after_type_inference(before, after)
  node = Parser.parse(before)
  result = infer_type node
  expect(result.node.to_s.strip).to eq(after.strip)
end

def assert_syntax_error(str, message = nil, line = nil, column = nil, metafile = __FILE__, metaline = __LINE__)
  it "says syntax error on #{str.inspect}", metafile, metaline do
    begin
      parse str
      fail "expected SyntaxException to be raised", metafile, metaline
    rescue ex : SyntaxException
      expect(ex.message.not_nil!.includes?(message)).to be_true, metafile, metaline if message
      expect(ex.line_number).to eq(line), metafile, metaline if line
      expect(ex.column_number).to eq(column), metafile, metaline if column
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
  result = result.source
  result = result[0 .. -2] if result.ends_with?(';')
  expect(result).to eq(expected)
end

def parse(string, wants_doc = false)
  parser = Parser.new(string)
  parser.wants_doc = wants_doc
  parser.parse
end

def build(code)
  node = parse code
  result = infer_type node
  result.program.build result.node, single_module: false
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

def run(code, filename = nil)
  # Code that requires the prelude doesn't run in LLVM's MCJIT
  # because of missing linked functions (which are available
  # in the current executable!), so instead we compile
  # the program and run it, printing the last
  # expression and using that to compare the result.
  if code.includes?(%(require "prelude"))
    ast = Parser.parse(code)
    assign = Assign.new(Var.new("__tempvar"), ast)
    call = Call.new(nil, "print!", Var.new("__tempvar"))
    code = Expressions.new([assign, call]).to_s

    tempfile = Tempfile.new("crystal-spec-output")
    output_filename = tempfile.path
    tempfile.close

    compiler = Compiler.new
    compiler.compile Compiler::Source.new("spec", code), output_filename

    output = `#{output_filename}`
    tempfile.delete

    SpecRunOutput.new(output)
  else
    Program.new.run(code, filename: filename)
  end
end
