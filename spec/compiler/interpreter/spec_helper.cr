{% skip_file if flag?(:without_interpreter) %}
require "../spec_helper"
require "compiler/crystal/interpreter/*"

def interpret(code, *, prelude = "primitives", file = __FILE__, line = __LINE__)
  if prelude == "primitives"
    context, value = interpret_with_context(code)
    value.value
  else
    interpret_in_separate_process(code, prelude, file: file, line: line)
  end
end

def interpret_with_context(code)
  repl = Crystal::Repl.new
  repl.prelude = "primitives"

  value = repl.run_code(code)
  {repl.context, value}
end

# FIXME: The following is a dirty hack to work around GC issues in interpreted programs. https://github.com/crystal-lang/crystal/issues/11602
# In a nutshell, `interpret_in_separate_process` below calls this same process with an extra option that causes
# the interpretation of the code from stdin, reading the output from stdout. That string is used as the result of
# the program being tested.
def Spec.option_parser
  option_parser = previous_def
  option_parser.on("", "--interpret-code PRELUDE", "Execute interpreted code") do |prelude|
    code = STDIN.gets_to_end

    repl = Crystal::Repl.new
    repl.prelude = prelude

    print repl.run_code(code)
    exit
  end
  option_parser
end

def interpret_in_separate_process(code, prelude, file = __FILE__, line = __LINE__)
  input = IO::Memory.new(code)
  output = IO::Memory.new
  error = IO::Memory.new
  executable = Process.executable_path || fail "Can't find executable path of current process"
  process = Process.new(executable, ["--interpret-code", prelude], input: input, output: output, error: error)

  status = process.wait
  unless status.success?
    fail error.rewind.gets_to_end + output.rewind.gets_to_end, file: file, line: line
  end

  output.rewind.gets_to_end
end
