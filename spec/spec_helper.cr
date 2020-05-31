{% raise("Please use `make spec` or `bin/crystal` when running specs, or set the i_know_what_im_doing flag if you know what you're doing") unless env("CRYSTAL_HAS_WRAPPER") || flag?("i_know_what_im_doing") %}

ENV["CRYSTAL_PATH"] = "#{__DIR__}/../src"

require "spec"

{% skip_file if flag?(:win32) %}

require "../src/compiler/crystal/**"
require "./support/syntax"

class Crystal::Program
  def union_of(type1, type2, type3)
    union_of([type1, type2, type3] of Type).not_nil!
  end

  def proc_of(type1 : Type)
    proc_of([type1] of Type)
  end

  def proc_of(type1 : Type, type2 : Type)
    proc_of([type1, type2] of Type)
  end

  def generic_class(name, *type_vars)
    types[name].as(GenericClassType).instantiate(type_vars.to_a.map &.as(TypeVar))
  end

  def generic_module(name, *type_vars)
    types[name].as(GenericModuleType).instantiate(type_vars.to_a.map &.as(TypeVar))
  end
end

record SemanticResult,
  program : Program,
  node : ASTNode

def assert_type(str, *, inject_primitives = true, flags = nil, file = __FILE__, line = __LINE__)
  result = semantic(str, flags: flags, inject_primitives: inject_primitives)
  program = result.program
  expected_type = with program yield program
  node = result.node
  if node.is_a?(Expressions)
    node = node.last
  end
  node.type.should eq(expected_type), file: file, line: line
  result
end

def semantic(code : String, wants_doc = false, inject_primitives = true, flags = nil, filename = nil)
  node = parse(code, wants_doc: wants_doc, filename: filename)
  node = inject_primitives(node) if inject_primitives
  semantic node, wants_doc: wants_doc, flags: flags
end

private def inject_primitives(node : ASTNode)
  req = Crystal::Require.new("primitives")
  case node
  when Crystal::Expressions
    node.expressions.unshift req
    node
  when Crystal::Nop
    node
  else
    Crystal::Expressions.new [req, node] of ASTNode
  end
end

def semantic(node : ASTNode, wants_doc = false, flags = nil)
  program = new_program
  program.flags.concat(flags.split) if flags
  program.wants_doc = wants_doc
  node = program.normalize node
  node = program.semantic node
  SemanticResult.new(program, node)
end

def assert_normalize(from, to, flags = nil)
  program = new_program
  program.flags.concat(flags.split) if flags
  normalizer = Normalizer.new(program)
  from_nodes = Parser.parse(from)
  to_nodes = program.normalize(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
  to_nodes
end

def assert_expand(from : String, to)
  assert_expand Parser.parse(from), to
end

def assert_expand(from_nodes : ASTNode, to)
  to_nodes = LiteralExpander.new(new_program).expand(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def assert_expand_second(from : String, to)
  node = (Parser.parse(from).as(Expressions))[1]
  assert_expand node, to
end

def assert_expand_third(from : String, to)
  node = (Parser.parse(from).as(Expressions))[2]
  assert_expand node, to
end

def assert_error(str, message, inject_primitives = true, file = __FILE__, line = __LINE__)
  expect_raises TypeException, message, file, line do
    semantic str, inject_primitives: inject_primitives
  end
end

def assert_no_errors(*args)
  semantic(*args)
end

def warnings_result(code)
  output_filename = Crystal.temp_executable("crystal-spec-output")

  compiler = create_spec_compiler
  compiler.warnings = Warnings::All
  compiler.error_on_warnings = false
  compiler.prelude = "empty" # avoid issues in the current std lib
  compiler.color = false
  apply_program_flags(compiler.flags)
  result = compiler.compile Compiler::Source.new("code.cr", code), output_filename

  result.program.warning_failures
end

def assert_warning(code, message, file = __FILE__, line = __LINE__)
  warning_failures = warnings_result(code)
  warning_failures.size.should eq(1), file, line
  warning_failures[0].should start_with(message), file, line
end

def assert_macro(macro_args, macro_body, call_args, expected, expected_pragmas = nil, flags = nil)
  assert_macro(macro_args, macro_body, expected, expected_pragmas, flags) { call_args }
end

def assert_macro(macro_args, macro_body, expected, expected_pragmas = nil, flags = nil)
  program = new_program
  program.flags.concat(flags.split) if flags
  sub_node = yield program
  assert_macro_internal program, sub_node, macro_args, macro_body, expected, expected_pragmas
end

def assert_macro_internal(program, sub_node, macro_args, macro_body, expected, expected_pragmas)
  macro_def = "macro foo(#{macro_args});#{macro_body};end"
  a_macro = Parser.parse(macro_def).as(Macro)

  call = Call.new(nil, "", sub_node)
  result, result_pragmas = program.expand_macro a_macro, call, program, program
  result = result.chomp(';')
  result.should eq(expected)
  result_pragmas.should eq(expected_pragmas) if expected_pragmas
end

def codegen(code, inject_primitives = true, debug = Crystal::Debug::None, filename = __FILE__)
  result = semantic code, inject_primitives: inject_primitives, filename: filename
  result.program.codegen(result.node, single_module: false, debug: debug)[""].mod
end

private def new_program
  program = Program.new
  program.color = false
  apply_program_flags(program.flags)
  program
end

# Use CRYSTAL_SPEC_COMPILER_FLAGS env var to run the compiler specs
# against a compiler with the specified options.
# Separate flags with a space.
# Using CRYSTAL_SPEC_COMPILER_FLAGS="foo bar" will mimic -Dfoo -Dbar options.
private def apply_program_flags(target)
  ENV["CRYSTAL_SPEC_COMPILER_FLAGS"]?.try { |f| target.concat(f.split) }
end

private def spec_compiler_threads
  ENV["CRYSTAL_SPEC_COMPILER_THREADS"]?.try(&.to_i)
end

private def encode_program_flags : String
  program_flags_options.join(' ')
end

def program_flags_options : Array(String)
  f = [] of String
  apply_program_flags(f)
  options = f.map { |x| "-D#{x}" }
  if (n_threads = spec_compiler_threads)
    options << "--threads=#{n_threads}"
  end
  options
end

class Crystal::SpecRunOutput
  @output : String

  def initialize(@output)
  end

  def to_string
    @output
  end

  delegate to_i, to_u64, to_f, to_f32, to_f64, to: @output

  def to_b
    @output == "true"
  end
end

def create_spec_compiler
  compiler = Compiler.new
  if (n_threads = spec_compiler_threads)
    compiler.n_threads = n_threads
  end

  compiler
end

def run(code, filename = nil, inject_primitives = true, debug = Crystal::Debug::None, flags = nil)
  if inject_primitives
    code = %(require "primitives"\n#{code})
  end

  # Code that requires the prelude doesn't run in LLVM's MCJIT
  # because of missing linked functions (which are available
  # in the current executable!), so instead we compile
  # the program and run it, printing the last
  # expression and using that to compare the result.
  if code.includes?(%(require "prelude")) || flags
    ast = Parser.parse(code).as(Expressions)
    last = ast.expressions.last
    assign = Assign.new(Var.new("__tempvar"), last)
    call = Call.new(nil, "print", Var.new("__tempvar"))
    exps = Expressions.new([assign, call] of ASTNode)
    ast.expressions[-1] = exps
    code = ast.to_s

    output_filename = Crystal.temp_executable("crystal-spec-output")

    compiler = create_spec_compiler
    compiler.debug = debug
    compiler.flags.concat flags if flags
    apply_program_flags(compiler.flags)
    compiler.compile Compiler::Source.new("spec", code), output_filename

    output = `#{Process.quote(output_filename)}`
    File.delete(output_filename)

    SpecRunOutput.new(output)
  else
    new_program.run(code, filename: filename, debug: debug)
  end
end

def build(code)
  code_file = File.tempname("build_and_run_code")

  # write code to the temp file
  File.write(code_file, code)

  binary_file = File.tempname("build_and_run_bin")

  `bin/crystal build #{encode_program_flags} #{Process.quote(code_file.path.to_s)} -o #{Process.quote(binary_file.path.to_s)}`
  File.exists?(binary_file).should be_true

  yield binary_file
ensure
  File.delete(code_file) if code_file
  File.delete(binary_file) if binary_file
end

def build_and_run(code)
  build(code) do |binary_file|
    out_io, err_io = IO::Memory.new, IO::Memory.new
    status = Process.run(binary_file, output: out_io, error: err_io)

    {status, out_io.to_s, err_io.to_s}
  end
end

def test_c(c_code, crystal_code)
  c_filename = "#{__DIR__}/temp_abi.c"
  o_filename = "#{__DIR__}/temp_abi.o"
  begin
    File.write(c_filename, c_code)

    `#{Crystal::Compiler::CC} #{Process.quote(c_filename)} -c -o #{Process.quote(o_filename)}`.should be_truthy

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
