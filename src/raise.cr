require "c/stdio"
require "c/stdlib"
require "callstack"

CallStack.skip(__FILE__)

private struct LEBReader
  def initialize(@data : UInt8*)
  end

  def data
    @data
  end

  def read_uint8
    value = @data.value
    @data += 1
    value
  end

  def read_uint32
    value = @data.as(UInt32*).value
    @data += 4
    value
  end

  def read_uleb128
    result = 0_u64
    shift = 0
    while true
      byte = read_uint8
      result |= ((0x7f_u64 & byte) << shift)
      break if (byte & 0x80_u8) == 0
      shift += 7
    end
    result
  end
end

{% if flag?(:arm) %}
  # On ARM EHABI the personality routine is responsible for actually
  # unwinding a single stack frame before returning (ARM EHABI Sec. 6.1).
  private macro __crystal_continue_unwind
    if LibUnwind.__gnu_unwind_frame(ucb, context) != LibUnwind::ReasonCode::NO_REASON
      return LibUnwind::ReasonCode::FAILURE
    end
    #puts "continue"
    return LibUnwind::ReasonCode::CONTINUE_UNWIND
  end

  # :nodoc:
  fun __crystal_personality(state : LibUnwind::State, ucb : LibUnwind::ControlBlock*, context : LibUnwind::Context) : LibUnwind::ReasonCode
    #puts "\n__crystal_personality(#{state}, #{ucb}, #{context})"

    case LibUnwind::State.new(state.value & LibUnwind::State::ACTION_MASK.value)
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
      exit(-1)
    end

    if state.force_unwind?
      actions |= LibUnwind::Action::FORCE_UNWIND
    end

    start = __crystal_get_region_start(ucb)
    lsd = __crystal_get_language_specific_data(ucb)

    ip = __crystal_unwind_get_ip(context)
    throw_offset = ip - 1 - start

    leb = LEBReader.new(lsd)
    leb.read_uint8               # @LPStart encoding
    if leb.read_uint8 != 0xff_u8 # @TType encoding
      leb.read_uleb128           # @TType base offset
    end
    leb.read_uint8                     # CS Encoding
    cs_table_length = leb.read_uleb128 # CS table length
    cs_table_end = leb.data + cs_table_length

    while leb.data < cs_table_end
      cs_offset = leb.read_uint32
      cs_length = leb.read_uint32
      cs_addr = leb.read_uint32
      action = leb.read_uleb128
      #puts "cs_offset: #{cs_offset}, cs_length: #{cs_length}, cs_addr: #{cs_addr}, action: #{action}"

      if cs_addr != 0
        if cs_offset <= throw_offset && throw_offset <= cs_offset + cs_length
          if actions.includes? LibUnwind::Action::SEARCH_PHASE
            #puts "found"
            return LibUnwind::ReasonCode::HANDLER_FOUND
          end

          if actions.includes? LibUnwind::Action::HANDLER_FRAME
            __crystal_unwind_set_gr(context, LibUnwind::EH_REGISTER_0, ucb.address.to_u32)
            __crystal_unwind_set_gr(context, LibUnwind::EH_REGISTER_1, ucb.value.exception_type_id.to_u32)
            __crystal_unwind_set_ip(context, start + cs_addr)
            #puts "install"
            return LibUnwind::ReasonCode::INSTALL_CONTEXT
          end
        end
      end
    end

    __crystal_continue_unwind
  end
{% else %}
  # :nodoc:
  fun __crystal_personality(version : Int32, actions : LibUnwind::Action, exception_class : UInt64, exception_object : LibUnwind::Exception*, context : Void*) : LibUnwind::ReasonCode
    start = LibUnwind.get_region_start(context)
    ip = LibUnwind.get_ip(context)
    throw_offset = ip - 1 - start
    lsd = LibUnwind.get_language_specific_data(context)
    #puts "Personality - actions : #{actions}, start: #{start}, ip: #{ip}, throw_offset: #{throw_offset}"

    leb = LEBReader.new(lsd)
    leb.read_uint8               # @LPStart encoding
    if leb.read_uint8 != 0xff_u8 # @TType encoding
      leb.read_uleb128           # @TType base offset
    end
    leb.read_uint8                     # CS Encoding
    cs_table_length = leb.read_uleb128 # CS table length
    cs_table_end = leb.data + cs_table_length

    while leb.data < cs_table_end
      cs_offset = leb.read_uint32
      cs_length = leb.read_uint32
      cs_addr = leb.read_uint32
      action = leb.read_uleb128
      #puts "cs_offset: #{cs_offset}, cs_length: #{cs_length}, cs_addr: #{cs_addr}, action: #{action}"

      if cs_addr != 0
        if cs_offset <= throw_offset && throw_offset <= cs_offset + cs_length
          if actions.includes? LibUnwind::Action::SEARCH_PHASE
            #puts "found"
            return LibUnwind::ReasonCode::HANDLER_FOUND
          end

          if actions.includes? LibUnwind::Action::HANDLER_FRAME
            LibUnwind.set_gr(context, LibUnwind::EH_REGISTER_0, exception_object.address)
            LibUnwind.set_gr(context, LibUnwind::EH_REGISTER_1, exception_object.value.exception_type_id)
            LibUnwind.set_ip(context, start + cs_addr)
            #puts "install"
            return LibUnwind::ReasonCode::INSTALL_CONTEXT
          end
        end
      end
    end

    #puts "continue"
    return LibUnwind::ReasonCode::CONTINUE_UNWIND
  end
{% end %}

# :nodoc:
@[Raises]
fun __crystal_raise(unwind_ex : LibUnwind::Exception*) : NoReturn
  ret = LibUnwind.raise_exception(unwind_ex)
  LibC.dprintf 2, "Failed to raise an exception: %s\n", ret.to_s
  CallStack.print_backtrace
  LibC.exit(ret)
end

# :nodoc:
fun __crystal_get_exception(unwind_ex : LibUnwind::Exception*) : UInt64
  unwind_ex.value.exception_object
end

# Raises the *exception*.
#
# This will set the exception's callstack if it hasn't been already.
# Re-raising a previously catched exception won't replace the callstack.
def raise(exception : Exception) : NoReturn
  exception.callstack ||= CallStack.new
  unwind_ex = Pointer(LibUnwind::Exception).malloc
  unwind_ex.value.exception_class = LibC::SizeT.zero
  unwind_ex.value.exception_cleanup = LibC::SizeT.zero
  unwind_ex.value.exception_object = exception.object_id
  unwind_ex.value.exception_type_id = exception.crystal_type_id
  __crystal_raise(unwind_ex)
end

# Raises an Exception with the *message*.
def raise(message : String) : NoReturn
  raise Exception.new(message)
end

# :nodoc:
fun __crystal_raise_string(message : UInt8*)
  raise String.new(message)
end
