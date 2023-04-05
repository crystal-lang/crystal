require "lib_c"

lib LibC
  fun _beginthreadex(security : Void*, stack_size : UInt, start_address : Void* -> UInt, arglist : Void*, initflag : UInt, thrdaddr : UInt*) : Void*
end
