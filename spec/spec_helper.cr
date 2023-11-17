{% raise("Please use `make test` or `bin/crystal` when running specs, or set the i_know_what_im_doing flag if you know what you're doing") unless env("CRYSTAL_HAS_WRAPPER") || flag?("i_know_what_im_doing") %}

ENV["CRYSTAL_PATH"] = "#{__DIR__}/../src"

require "spec"

require "compiler/requires"
require "./support/syntax"
require "./support/tempfile"
require "./support/win32"

class Crystal::Program
  setter temp_var_counter

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

def assert_type(str, *, inject_primitives = false, flags = nil, file = __FILE__, line = __LINE__, &)
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

def semantic(code : String, wants_doc = false, inject_primitives = false, flags = nil, filename = nil)
  warnings = WarningCollection.new
  node = parse(code, wants_doc: wants_doc, filename: filename, warnings: warnings)
  node = inject_primitives(node) if inject_primitives
  semantic node, warnings: warnings, wants_doc: wants_doc, flags: flags
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

def semantic(node : ASTNode, *, warnings = nil, wants_doc = false, flags = nil)
  program = new_program
  program.warnings = warnings if warnings
  program.flags.concat(flags.split) if flags
  program.wants_doc = wants_doc
  node = program.normalize node
  node = program.semantic node
  SemanticResult.new(program, node)
end

def assert_normalize(from, to, flags = nil, *, file = __FILE__, line = __LINE__)
  program = new_program
  program.flags.concat(flags.split) if flags
  from_nodes = Parser.parse(from)
  to_nodes = program.normalize(from_nodes)
  to_nodes_str = to_nodes.to_s.strip
  to_nodes_str.should eq(to.strip), file: file, line: line

  # first idempotency check: the result should be fully normalized
  to_nodes_str2 = program.normalize(to_nodes).to_s.strip
  unless to_nodes_str2 == to_nodes_str
    fail "Idempotency failed:\nBefore: #{to_nodes_str.inspect}\nAfter:  #{to_nodes_str2.inspect}", file: file, line: line
  end

  # second idempotency check: if the normalizer mutates the original node,
  # further normalizations should not produce a different result
  program.temp_var_counter = 0
  to_nodes_str2 = program.normalize(from_nodes).to_s.strip
  unless to_nodes_str2 == to_nodes_str
    fail "Idempotency failed:\nBefore: #{to_nodes_str.inspect}\nAfter:  #{to_nodes_str2.inspect}", file: file, line: line
  end

  to_nodes
end

def assert_expand(from : String, to, *, flags = nil, file = __FILE__, line = __LINE__)
  assert_expand Parser.parse(from), to, flags: flags, file: file, line: line
end

def assert_expand(from_nodes : ASTNode, to, *, flags = nil, file = __FILE__, line = __LINE__)
  program = new_program
  program.flags.concat(flags.split) if flags
  to_nodes = LiteralExpander.new(program).expand(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip), file: file, line: line
end

def assert_expand_second(from : String, to, *, flags = nil, file = __FILE__, line = __LINE__)
  node = (Parser.parse(from).as(Expressions))[1]
  assert_expand node, to, flags: flags, file: file, line: line
end

def assert_expand_third(from : String, to, *, flags = nil, file = __FILE__, line = __LINE__)
  node = (Parser.parse(from).as(Expressions))[2]
  assert_expand node, to, flags: flags, file: file, line: line
end

def assert_expand_named(from : String, to, *, generic = nil, flags = nil, file = __FILE__, line = __LINE__)
  program = new_program
  program.flags.concat(flags.split) if flags
  from_nodes = Parser.parse(from)
  generic_type = generic.path if generic
  case from_nodes
  when ArrayLiteral
    to_nodes = LiteralExpander.new(program).expand_named(from_nodes, generic_type)
  when HashLiteral
    to_nodes = LiteralExpander.new(program).expand_named(from_nodes, generic_type)
  else
    fail "Expected: ArrayLiteral | HashLiteral, got: #{from_nodes.class}", file: file, line: line
  end
  to_nodes.to_s.strip.should eq(to.strip), file: file, line: line
end

def assert_error(str, message = nil, *, inject_primitives = false, flags = nil, file = __FILE__, line = __LINE__)
  expect_raises TypeException, message, file, line do
    semantic str, inject_primitives: inject_primitives, flags: flags
  end
end

def assert_no_errors(*args, **opts)
  semantic(*args, **opts)
end

def warnings_result(code)
  semantic(code).program.warnings.infos
end

def assert_warning(code, message, *, file = __FILE__, line = __LINE__)
  warning_failures = warnings_result(code)
  warning_failures.size.should eq(1), file: file, line: line
  warning_failures[0].should contain(message), file: file, line: line
end

def assert_macro(macro_body, expected, args = nil, *, expected_pragmas = nil, flags = nil, file = __FILE__, line = __LINE__)
  assert_macro(macro_body, expected, expected_pragmas: expected_pragmas, flags: flags, file: file, line: line) { args }
end

def assert_macro(macro_body, expected, *, expected_pragmas = nil, flags = nil, file = __FILE__, line = __LINE__, &)
  program, a_macro, call = prepare_macro_call(macro_body, flags) { |program| yield program }
  result, result_pragmas = program.expand_macro(a_macro, call, program, program)
  result = result.chomp(';')
  result.should eq(expected), file: file, line: line
  result_pragmas.should eq(expected_pragmas), file: file, line: line if expected_pragmas
end

def assert_macro_error(macro_body, message = nil, args = nil, *, flags = nil, file = __FILE__, line = __LINE__)
  assert_macro_error(macro_body, message, flags: flags, file: file, line: line) { args }
end

def assert_macro_error(macro_body, message = nil, *, flags = nil, file = __FILE__, line = __LINE__, &)
  program, a_macro, call = prepare_macro_call(macro_body, flags) { |program| yield program }
  expect_raises(Crystal::TypeException, message, file: file, line: line) do
    program.expand_macro(a_macro, call, program, program)
  end
end

def prepare_macro_call(macro_body, flags = nil, &)
  program = new_program
  program.flags.concat(flags.split) if flags
  args = yield program

  macro_params = args.try &.keys.join(", ")
  call_args = [] of ASTNode
  call_args.concat(args.values) if args

  a_macro = Parser.parse("macro foo(#{macro_params});#{macro_body};end").as(Macro)
  call = Call.new(nil, "", call_args)

  {program, a_macro, call}
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

  delegate to_i, to_i64, to_u64, to_f, to_f32, to_f64, to: @output

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

def run(code, filename = nil, inject_primitives = true, debug = Crystal::Debug::None, flags = nil, *, file = __FILE__)
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

    compiler = create_spec_compiler
    compiler.debug = debug
    compiler.flags.concat flags if flags
    apply_program_flags(compiler.flags)

    with_temp_executable("crystal-spec-output", file: file) do |output_filename|
      compiler.compile Compiler::Source.new("spec", code), output_filename

      output = `#{Process.quote(output_filename)}`
      return SpecRunOutput.new(output)
    end
  else
    new_program.run(code, filename: filename, debug: debug)
  end
end

def test_c(c_code, crystal_code, *, file = __FILE__, &)
  with_temp_c_object_file(c_code, file: file) do |o_filename|
    yield run(%(
    require "prelude"

    @[Link(ldflags: #{o_filename.inspect})]
    #{crystal_code}
    ))
  end
end
