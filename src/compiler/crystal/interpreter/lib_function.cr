require "./repl"

# Information about a C function that needs to be called.
class Crystal::Repl::LibFunction
  # Symbol returned by dlopen and dlsym that is a pointer
  # to the actual function.
  getter symbol : Void*

  # The FFI call interface definition to call the C function
  getter call_interface : FFI::CallInterface

  # Bytesize for each argument in the call
  getter args_bytesizes : Array(Int32)

  # Bytesize for the call's return value
  getter return_bytesize : Int32

  def initialize(
    @symbol : Void*,
    @call_interface : FFI::CallInterface,
    @args_bytesizes : Array(Int32),
    @return_bytesize : Int32,
  )
  end
end
