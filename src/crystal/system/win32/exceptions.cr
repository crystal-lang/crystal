{% begin %}
  @[Link({{ flag?(:static) ? "libvcruntime" : "vcruntime" }})]
{% end %}
lib LibC
  fun _CxxThrowException(ex : Void*, throw_info : Void*) : NoReturn
end

@[Primitive(:throw_info)]
def throw_info : Void*
end

# :nodoc:
# @[Raises]
# fun __crystal_raise(unwind_ex : LibUnwind::Exception*) : NoReturn
#   Crystal::System::Exceptions.panic "EXITING: __crystal_raise called"
# end

# :nodoc:
def raise_without_backtrace(exception : Exception) : NoReturn
  LibC._CxxThrowException(pointerof(exception).as(Void*), throw_info)
end
