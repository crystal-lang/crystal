require "./repl"

class Crystal::Repl::FFIClosureContext
  getter interpreter : Interpreter
  getter compiled_def : CompiledDef

  def initialize(@interpreter : Interpreter, @compiled_def : CompiledDef)
  end
end
