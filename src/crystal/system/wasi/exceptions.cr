# :nodoc:
@[Raises]
fun __crystal_raise(ex : Void*) : NoReturn
  {% if compare_versions(Crystal::LLVM_VERSION, "24.0.0") < 0 %}
    Crystal::System.panic! "EXITING: __crystal_raise called"
  {% else %}
    LibIntrinsics.wasm_throw(0, ex)
  {% end %}
end

# :nodoc:
def raise_without_backtrace(exception : Exception) : NoReturn
  LibIntrinsics.wasm_throw(0, exception.as(Void*)) # 0 == CPP_EXCEPTION tag
end
