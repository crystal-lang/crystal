# :nodoc:
fun __crystal_personality
  Crystal::System.print_error "EXITING: __crystal_personality called"
  LibC.exit(1)
end

# :nodoc:
@[Raises]
fun __crystal_raise(ex : Void*) : NoReturn
  {% if compare_versions(Crystal::LLVM_VERSION, "24.0.0") < 0 %}
    Crystal::System::Exceptions.panic "EXITING: __crystal_raise called"
  {% else %}
    LibIntrinsics.wasm_throw(0, ex)
  {% end %}
end

# :nodoc:
# fun __crystal_get_exception(ex : Void*) : UInt64
#  Crystal::System::Exceptions.panic "EXITING: __crystal_get_exception called"
#  0u64
# end

# :nodoc:
def raise_without_backtrace(exception : Exception) : NoReturn
  LibIntrinsics.wasm_throw(0, exception.as(Void*)) # 0 == CPP_EXCEPTION tag
end
