module Crystal::System::Exceptions
  struct LEBReader
    def initialize(@data : UInt8*)
    end

    def data : UInt8*
      @data
    end

    def read_uint8 : UInt8
      value = @data.value
      @data += 1
      value
    end

    def read_uint32 : UInt32
      value = @data.as(UInt32*).value
      @data += 4
      value
    end

    def read_uleb128 : UInt64
      result = 0_u64
      shift = 0
      while true
        byte = read_uint8
        result |= (0x7f_u64 & byte).unsafe_shl(shift)
        break if (byte & 0x80_u8) == 0
        shift &+= 7
      end
      result
    end
  end

  def self.personality(version : Int32, actions : LibUnwind::Action, exception_class : UInt64, exception_object : LibUnwind::Exception*, context : Void*) : LibUnwind::ReasonCode
    start = LibUnwind.get_region_start(context)
    ip = LibUnwind.get_ip(context)
    lsd = LibUnwind.get_language_specific_data(context)

    leb = LEBReader.new(lsd)
    reason = traverse_eh_table(leb, start, ip, actions) do |unwind_ip|
      LibUnwind.set_gr(context, LibUnwind::EH_REGISTER_0, exception_object.address)
      LibUnwind.set_gr(context, LibUnwind::EH_REGISTER_1, exception_object.value.exception_type_id)
      LibUnwind.set_ip(context, unwind_ip)
    end
    return reason if reason

    return LibUnwind::ReasonCode::CONTINUE_UNWIND
  end

  def self.traverse_eh_table(leb, start, ip, actions, &)
    # Ref: https://chromium.googlesource.com/native_client/pnacl-libcxxabi/+/master/src/cxa_personality.cpp

    throw_offset = ip - 1 - start

    lp_start_encoding = leb.read_uint8 # @LPStart encoding
    if lp_start_encoding != 0xff_u8
      System.panic! "Unexpected encoding for LPStart: 0x%x\n", lp_start_encoding
    end

    if leb.read_uint8 != 0xff_u8 # @TType encoding
      leb.read_uleb128           # @TType base offset
    end

    cs_encoding = leb.read_uint8 # CS Encoding (1: uleb128, 3: uint32)
    if cs_encoding != 1 && cs_encoding != 3
      System.panic! "Unexpected CS encoding: 0x%x\n", cs_encoding
    end

    cs_table_length = leb.read_uleb128 # CS table length
    cs_table_end = leb.data + cs_table_length.to_i64

    while leb.data < cs_table_end
      cs_offset = cs_encoding == 3 ? leb.read_uint32 : leb.read_uleb128
      cs_length = cs_encoding == 3 ? leb.read_uint32 : leb.read_uleb128
      cs_addr = cs_encoding == 3 ? leb.read_uint32 : leb.read_uleb128
      action = leb.read_uleb128

      if cs_addr != 0
        if cs_offset <= throw_offset && throw_offset <= cs_offset + cs_length
          if actions.includes? LibUnwind::Action::SEARCH_PHASE
            return LibUnwind::ReasonCode::HANDLER_FOUND
          end

          if actions.includes? LibUnwind::Action::HANDLER_FRAME
            unwind_ip = start + cs_addr
            yield unwind_ip
            return LibUnwind::ReasonCode::INSTALL_CONTEXT
          end
        end
      end
    end

    nil
  end
end

{% if flag?(:arm) %}
  # On ARM EHABI the personality routine is responsible for actually unwinding a
  # single stack frame before returning (ARM EHABI Sec. 6.1).
  private macro __crystal_continue_unwind
    if LibUnwind.__gnu_unwind_frame(ucb, context) != LibUnwind::ReasonCode::NO_REASON
      return LibUnwind::ReasonCode::FAILURE
    end
    return LibUnwind::ReasonCode::CONTINUE_UNWIND
  end

  # :nodoc:
  fun __crystal_personality(state : LibUnwind::State, ucb : LibUnwind::ControlBlock*, context : LibUnwind::Context) : LibUnwind::ReasonCode
    value = state.value & LibUnwind::State::ACTION_MASK.value

    case LibUnwind::State.new(value)
    when LibUnwind::State::VIRTUAL_UNWIND_FRAME
      if state.force_unwind?
        __crystal_continue_unwind
      else
        actions = LibUnwind::Action::SEARCH_PHASE
      end
    when LibUnwind::State::UNWIND_FRAME_STARTING
      actions = LibUnwind::Action::HANDLER_FRAME
    when LibUnwind::State::UNWIND_FRAME_RESUME
      __crystal_continue_unwind
    else
      Crystal::System.panic! "Unexpected unwind state: %d\n", value
    end

    if state.force_unwind?
      actions |= LibUnwind::Action::FORCE_UNWIND
    end

    start = __crystal_get_region_start(ucb)
    lsd = __crystal_get_language_specific_data(ucb)

    ip = __crystal_unwind_get_ip(context)
    leb = Crystal::System::Exceptions::LEBReader.new(lsd)

    reason = Crystal::System::Exceptions.traverse_eh_table(leb, start, ip, actions) do |unwind_ip|
      __crystal_unwind_set_gr(context, LibUnwind::EH_REGISTER_0, ucb.address.to_u32)
      __crystal_unwind_set_gr(context, LibUnwind::EH_REGISTER_1, ucb.value.exception_type_id.to_u32)
      __crystal_unwind_set_ip(context, unwind_ip)
    end
    return reason if reason

    __crystal_continue_unwind
  end
{% elsif flag?(:win32) && flag?(:gnu) %}
  require "c/winnt"

  lib LibUnwind
    alias PersonalityFn = Int32, Action, UInt64, Exception*, Void* -> ReasonCode
    fun _GCC_specific_handler(ms_exc : LibC::EXCEPTION_RECORD64*, this_frame : Void*, ms_orig_context : LibC::CONTEXT*, ms_disp : LibC::DISPATCHER_CONTEXT*, gcc_per : PersonalityFn) : LibC::EXCEPTION_DISPOSITION
  end

  # :nodoc:
  fun __crystal_personality(ms_exc : LibC::EXCEPTION_RECORD64*, this_frame : Void*, ms_orig_context : LibC::CONTEXT*, ms_disp : LibC::DISPATCHER_CONTEXT*) : LibC::EXCEPTION_DISPOSITION
    LibUnwind._GCC_specific_handler(ms_exc, this_frame, ms_orig_context, ms_disp, ->Crystal::System::Exceptions.personality(Int32, LibUnwind::Action, UInt64, LibUnwind::Exception*, Void*))
  end
{% else %}
  # :nodoc:
  fun __crystal_personality(version : Int32, actions : LibUnwind::Action, exception_class : UInt64, exception_object : LibUnwind::Exception*, context : Void*) : LibUnwind::ReasonCode
    Crystal::System::Exceptions.personality(version, actions, exception_class, exception_object, context)
  end
{% end %}

# :nodoc:
fun __crystal_get_exception(unwind_ex : LibUnwind::Exception*) : UInt64
  unwind_ex.value.exception_object.address
end

@[Raises]
fun __crystal_raise(unwind_ex : LibUnwind::Exception*) : NoReturn
  LibUnwind.raise_exception(unwind_ex)
  Crystal::System.panic! "BUG: failed to raise an exception\n"
end

# :nodoc:
def raise_without_backtrace(exception : Exception) : NoReturn
  unwind_ex = Pointer(LibUnwind::Exception).malloc(1_u64)
  unwind_ex.value.exception_class = 0
  unwind_ex.value.exception_cleanup = 0
  unwind_ex.value.exception_object = exception.as(Void*)
  unwind_ex.value.exception_type_id = exception.crystal_type_id
  __crystal_raise(unwind_ex)
end
