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

  fun unwind_raise_exception = _Unwind_RaiseException(ex : UnwindException*) : NoReturn
  fun unwind_get_region_start = _Unwind_GetRegionStart(context : Void*) : UInt64
  fun unwind_get_ip = _Unwind_GetIP(context : Void*) : UInt64
  fun unwind_set_ip = _Unwind_SetIP(context : Void*, ip : UInt64) : UInt64
  fun unwind_get_language_specific_data = _Unwind_GetLanguageSpecificData(context : Void*) : UInt8*
end

class LEBReader
  getter :data

  def initialize(data)
    @data = data
  end

  def read_uint8
    value = @data.as(UInt8).value
    @data += 1
    value
  end

  def read_uint32
    value = @data.as(UInt32).value
    @data += 4
    value
  end

  def read_uleb128
    result = 0_u64;
    shift = 0;
    while true
      byte = read_uint8
      result |= ((0x7f_u64 & byte) << shift);
      break if (byte & 0x80_u8) == 0
      shift += 7
    end
    result
  end
end

fun __crystal_personality(version : Int32, actions : Int32, exception_class : UInt64, exception_object : ABI::UnwindException*, context : Void*) : Int32
  # puts "PERSONALITY: version: #{version}, actions: #{actions}, exception_class: #{exception_class}, exception_object: #{exception_object.address}"
  if (actions & ABI::UA_SEARCH_PHASE) > 0
    return ABI::URC_HANDLER_FOUND

  elsif (actions & ABI::UA_HANDLER_FRAME) > 0
    start = ABI.unwind_get_region_start(context)
    ip = ABI.unwind_get_ip(context)
    throw_offset = ip - 1 - start
    lsd = ABI.unwind_get_language_specific_data(context)

    reader = LEBReader.new(lsd)

    reader.read_uint8 # @LPStart encoding
    if reader.read_uint8 != 0xff_u8 # @TType encoding
      reader.read_uleb128 # @TType base offset
    end
    reader.read_uint8 # CS Encoding
    cs_table_length = reader.read_uleb128 # CS table length

    cs_table_end = reader.data + cs_table_length
    while reader.data < cs_table_end
      cs_offset = reader.read_uint32
      cs_length = reader.read_uint32
      cs_addr = reader.read_uint32
      action = reader.read_uleb128

      if cs_offset <= throw_offset && throw_offset <= cs_offset + cs_length
        if cs_addr != 0
          ABI.unwind_set_ip(context, start + cs_addr)
        end
      end
    end

    return ABI::URC_INSTALL_CONTEXT

  else
    ABI::URC_NO_REASON
  end
end

fun __crystal_raise : NoReturn
  ex = ABI::UnwindException.new
  ex.exception_class = 0_u64
  # ex.exception_cleanup = nil
  ABI.unwind_raise_exception(ex.ptr)
end

def raise(msg)
  __crystal_raise
end
