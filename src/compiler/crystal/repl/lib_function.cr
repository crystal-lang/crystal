require "./repl"

class Crystal::Repl::LibFunction
  getter def : Def
  getter symbol : Void*
  getter call_interface : FFI::CallInterface

  def initialize(@def : Def, @symbol : Void*, @call_interface : FFI::CallInterface)
  end
end
