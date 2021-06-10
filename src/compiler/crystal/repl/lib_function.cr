require "./repl"

class Crystal::Repl::LibFunction
  getter def : Def
  getter symbol : Void*
  getter call_interface : FFI::CallInterface
  getter args_bytesizes : Array(Int32)

  def initialize(
    @def : Def,
    @symbol : Void*,
    @call_interface : FFI::CallInterface,
    @args_bytesizes : Array(Int32)
  )
  end
end
