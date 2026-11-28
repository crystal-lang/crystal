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
def raise_without_backtrace(exception : Exception) : NoReturn
  LibC._CxxThrowException(pointerof(exception).as(Void*), throw_info)
end
