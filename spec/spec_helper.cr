{% raise("Please use `make spec` or `bin/crystal` when running specs, or set the i_know_what_im_doing flag if you know what you're doing") unless env("CRYSTAL_HAS_WRAPPER") || flag?("i_know_what_im_doing") %}

ENV["CRYSTAL_PATH"] = "#{__DIR__}/../src"

require "spec"
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
  node : ASTNode,
  type : Type

def assert_type(str, flags = nil, inject_primitives = true)
  result = semantic_result(str, flags, inject_primitives: inject_primitives)
  program = result.program
  expected_type = with program yield program
  result.type.should eq(expected_type)
  result
end

def semantic(code : String, wants_doc = false, inject_primitives = true)
  code = inject_primitives(code) if inject_primitives
  semantic parse(code, wants_doc: wants_doc), wants_doc: wants_doc
end

def semantic(node : ASTNode, wants_doc = false)
  program = Program.new
  program.wants_doc = wants_doc
  node = program.normalize node
  node = program.semantic node
  SemanticResult.new(program, node, node.type)
end

def semantic_result(str, flags = nil, inject_primitives = true)
  str = inject_primitives(str) if inject_primitives
  program = Program.new
  program.flags = flags if flags
  input = parse str
  input = program.normalize input
  input = program.semantic input
  input_type = input.is_a?(Expressions) ? input.last.type : input.type
  SemanticResult.new(program, input, input_type)
end

def assert_normalize(from, to, flags = nil)
  program = Program.new
  program.flags = flags if flags
  normalizer = Normalizer.new(program)
  from_nodes = Parser.parse(from)
  to_nodes = program.normalize(from_nodes)
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
  node = (Parser.parse(from).as(Expressions))[1]
  assert_expand node, to
end

def assert_expand_third(from : String, to)
  node = (Parser.parse(from).as(Expressions))[2]
  assert_expand node, to
end

def assert_after_cleanup(before, after)
  # before = inject_primitives(before)
  node = Parser.parse(before)
  result = semantic node
  result.node.to_s.strip.should eq(after.strip)
end

def assert_error(str, message, inject_primitives = true)
  str = inject_primitives(str) if inject_primitives
  nodes = parse str
  expect_raises TypeException, message do
    semantic nodes
  end
end

def assert_macro(macro_args, macro_body, call_args, expected, flags = nil)
  assert_macro(macro_args, macro_body, expected, flags) { call_args }
end

def assert_macro(macro_args, macro_body, expected, flags = nil)
  program = Program.new
  program.flags = flags if flags
  sub_node = yield program
  assert_macro_internal program, sub_node, macro_args, macro_body, expected
end

def assert_macro_internal(program, sub_node, macro_args, macro_body, expected)
  macro_def = "macro foo(#{macro_args});#{macro_body};end"
  a_macro = Parser.parse(macro_def).as(Macro)

  call = Call.new(nil, "", sub_node)
  result = program.expand_macro a_macro, call, program, program
  result = result.chomp(';')
  result.should eq(expected)
end

def codegen(code, inject_primitives = true, debug = Crystal::Debug::None)
  code = inject_primitives(code) if inject_primitives
  node = parse code
  result = semantic node
  result.program.codegen(result.node, single_module: false, debug: debug)[""].mod
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

def run(code, filename = nil, inject_primitives = true, debug = Crystal::Debug::None)
  code = inject_primitives(code) if inject_primitives

  # Code that requires the prelude doesn't run in LLVM's MCJIT
  # because of missing linked functions (which are available
  # in the current executable!), so instead we compile
  # the program and run it, printing the last
  # expression and using that to compare the result.
  if code.includes?(%(require "prelude"))
    build_executable(code, debug: debug, print: true) do |output_filename|
      output = `#{output_filename}`
      SpecRunOutput.new(output)
    end
  else
    Program.new.run(code, filename: filename, debug: debug)
  end
end

abstract class DebugLineCheck
  abstract def matches?(output)

  def self.from(line)
    if line.starts_with?("/")
      regex = line[1..-1]
      if regex.ends_with?("/")
        regex = regex[0..-2]
      end
      RegexLineCheck.new(regex)
    else
      StringLineCheck.new(line)
    end
  end
end

class StringLineCheck < DebugLineCheck
  def initialize(@line : String)
  end

  def matches?(output)
    output == @line
  end

  def to_s(io)
    @line.to_s(io)
  end
end

class RegexLineCheck < DebugLineCheck
  def initialize(line)
    @regex = Regex.new(line)
  end

  def matches?(output)
    @regex.match(output)
  end

  def to_s(io)
    @regex.inspect(io)
  end
end

def debug(script, code)
  code = code.strip
  build_executable(code, debug: Crystal::Debug::Default) do |output_filename|
    script_filename = Crystal.tempfile("debug-script")
    checks = [] of DebugLineCheck
    File.open(script_filename, "w") do |script_file|
      script.each_line do |script_line|
        script_line = script_line.strip
        next if script_line.empty?
        if script_line.starts_with?("(gdb)")
          script_file.puts script_line["(gdb)".size..-1].strip
        else
          checks << DebugLineCheck.from(script_line)
        end
      end
    end

    begin
      output = Process.run("gdb", ["-quiet", "-batch", "-nx", "-x", script_filename, output_filename]) do |gdb|
        gdb.output.gets_to_end
      end

      # GDB process should not fail to execute
      $?.exit_code.should_not eq(127)
      # and should have terminated normally (though maybe not successfully)
      $?.normal_exit?.should be_true

      last_output_matched = -1
      next_check_index = 0
      output.each_line.with_index do |output_line, output_index|
        output_line = output_line.chomp
        break if next_check_index >= checks.size
        if checks[next_check_index].matches?(output_line)
          last_output_matched = output_index
          next_check_index += 1
        end
      end

      unless next_check_index >= checks.size
        expected_lines = render_lines_with_pointer(checks, next_check_index - 1)
        output_lines = render_lines_with_pointer(output.lines.map(&.chomp), last_output_matched)
        msg = "Expected lines:\n#{expected_lines}\nActual output:\n#{output_lines}"
        fail "Failed to match all GDB output (last matched lines marked with >>>)\n#{msg}"
      end
    ensure
      File.delete(script_filename)
    end
  end
end

def render_lines_with_pointer(lines, pointer_index)
  String.build do |s|
    lines.each_with_index do |line, index|
      if index == pointer_index
        s << ">>> "
      else
        s << "    "
      end
      s << line
      s << "\n"
    end
  end
end

def build_executable(code, print = false, debug = Crystal::Debug::None)
  ast = Parser.parse(code).as(Expressions)
  if print
    last = ast.expressions.last
    assign = Assign.new(Var.new("__tempvar"), last)
    call = Call.new(nil, "print", Var.new("__tempvar"))
    exps = Expressions.new([assign, call] of ASTNode)
    ast.expressions[-1] = exps
    code = ast.to_s
  end

  output_filename = Crystal.tempfile("crystal-spec-output")

  compiler = Compiler.new
  compiler.debug = debug
  compiler.compile Compiler::Source.new("spec", code), output_filename

  begin
    yield output_filename
  ensure
    File.delete(output_filename)
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

private def inject_primitives(code)
  %(require "primitives"\n) + code
end
