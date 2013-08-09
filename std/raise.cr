lib ABI
  struct UnwindException
    exception_class : UInt64
    exception_cleanup : Void*
    private1 : UInt64
    private2 : UInt64
  end

  UA_SEARCH_PHASE = 1
  UA_CLEANUP_PHASE = 2
  UA_HANDLER_FRAME = 4
  UA_FORCE_UNWIND = 8

  URC_NO_REASON = 0
  URC_FOREIGN_EXCEPTION_CAUGHT = 1
  URC_FATAL_PHASE2_ERROR = 2
  URC_FATAL_PHASE1_ERROR = 3
  URC_NORMAL_STOP = 4
  URC_END_OF_STACK = 5
  URC_HANDLER_FOUND = 6
  URC_INSTALL_CONTEXT = 7
  URC_CONTINUE_UNWIND = 8

  fun unwind_raise_exception = _Unwind_RaiseException(ex : UnwindException*) : Int32
end


fun __crystal_personality(version : Int32, actions : Int32, exception_class : UInt64, exception_object : ABI::UnwindException*, context : Void*) : Int32
  puts "PERSONALITY: version: #{version}, actions: #{actions}, exception_class: #{exception_class}, exception_object: #{exception_object.address}"
  if (actions & ABI::UA_SEARCH_PHASE) > 0
    return ABI::URC_HANDLER_FOUND
  elsif (actions & ABI::UA_HANDLER_FRAME) > 0
    puts "??"
    return ABI::URC_INSTALL_CONTEXT
  else
    ABI::URC_NO_REASON
  end
end


# u = ABI::UnwindException.new
# personality(1, 1, 0_u64, u.ptr, Pointer(Void).malloc(1))


def raise(msg)
  puts "Raising..."
  ex = ABI::UnwindException.new
  ex.exception_class = 0_u64
  # ex.exception_cleanup = nil
  ABI.unwind_raise_exception(ex.ptr)

  exit 1
end
