lib ABI
  struct UnwindException
    exception_class : C::SizeT
    exception_cleanup : C::SizeT
    private1 : UInt64
    private2 : UInt64
    exception_object : UInt64
    exception_type_id : Int32
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

  ifdef x86_64
    EH_REGISTER_0 = 0
    EH_REGISTER_1 = 1
  else
    EH_REGISTER_0 = 0
    EH_REGISTER_1 = 2
  end

  fun unwind_raise_exception = _Unwind_RaiseException(ex : UnwindException*) : Int32
  fun unwind_get_region_start = _Unwind_GetRegionStart(context : Void*) : C::SizeT
  fun unwind_get_ip = _Unwind_GetIP(context : Void*) : C::SizeT
  fun unwind_set_ip = _Unwind_SetIP(context : Void*, ip : C::SizeT) : C::SizeT
  fun unwind_set_gr = _Unwind_SetGR(context : Void*, index : Int32, value : C::SizeT)
  fun unwind_get_language_specific_data = _Unwind_GetLanguageSpecificData(context : Void*) : UInt8*
end

module LEBReader
  def self.read_uint8(data)
    value = (data.value as UInt8*).value
    data.value += 1
    value
  end

  def self.read_uint32(data)
    value = (data.value as UInt32*).value
    data.value += 4
    value
  end

  def self.read_uleb128(data)
    result = 0_u64
    shift = 0
    while true
      byte = read_uint8(data)
      result |= ((0x7f_u64 & byte) << shift);
      break if (byte & 0x80_u8) == 0
      shift += 7
    end
    result
  end
end

fun __crystal_personality(version : Int32, actions : Int32, exception_class : UInt64, exception_object : ABI::UnwindException*, context : Void*) : Int32
  start = ABI.unwind_get_region_start(context)
  ip = ABI.unwind_get_ip(context)
  throw_offset = ip - 1 - start
  lsd = ABI.unwind_get_language_specific_data(context)
  # puts "Personality - actions : #{actions}, start: #{start}, ip: #{ip}, throw_offset: #{throw_offset}"

  LEBReader.read_uint8(pointerof(lsd)) # @LPStart encoding
  if LEBReader.read_uint8(pointerof(lsd)) != 0xff_u8 # @TType encoding
    LEBReader.read_uleb128(pointerof(lsd)) # @TType base offset
  end
  LEBReader.read_uint8(pointerof(lsd)) # CS Encoding
  cs_table_length = LEBReader.read_uleb128(pointerof(lsd)) # CS table length
  cs_table_end = lsd + cs_table_length

  while lsd < cs_table_end
    cs_offset = LEBReader.read_uint32(pointerof(lsd))
    cs_length = LEBReader.read_uint32(pointerof(lsd))
    cs_addr = LEBReader.read_uint32(pointerof(lsd))
    action = LEBReader.read_uleb128(pointerof(lsd))
    # puts "cs_offset: #{cs_offset}, cs_length: #{cs_length}, cs_addr: #{cs_addr}, action: #{action}"

    if cs_addr != 0
      if cs_offset <= throw_offset && throw_offset <= cs_offset + cs_length
        if (actions & ABI::UA_SEARCH_PHASE) > 0
          # puts "found"
          return ABI::URC_HANDLER_FOUND
        end

        if (actions & ABI::UA_HANDLER_FRAME) > 0
          ABI.unwind_set_gr(context, ABI::EH_REGISTER_0, exception_object.address.to_sizet)
          ABI.unwind_set_gr(context, ABI::EH_REGISTER_1, exception_object.value.exception_type_id.to_sizet)
          ABI.unwind_set_ip(context, start + cs_addr)
          # puts "install"
          return ABI::URC_INSTALL_CONTEXT
        end
      end
    end
  end

  # puts "continue"
  return ABI::URC_CONTINUE_UNWIND
end

fun __crystal_raise(unwind_ex : ABI::UnwindException*) : NoReturn
  ret = ABI.unwind_raise_exception(unwind_ex)
  puts "Could not raise"
  caller.each do |point|
    puts point
  end
  C.exit(ret)
end

fun __crystal_get_exception(unwind_ex : ABI::UnwindException*) : UInt64
  unwind_ex->exception_object
end

def raise(ex : Exception)
  unwind_ex = ABI::UnwindException.new
  unwind_ex->exception_class = 0.to_sizet
  unwind_ex->exception_cleanup = 0.to_sizet
  unwind_ex->exception_object = ex.object_id
  unwind_ex->exception_type_id = ex.crystal_type_id
  __crystal_raise(unwind_ex)
end

def raise(message : String)
  raise Exception.new(message)
end

fun __crystal_raise_string(message : Char*)
  raise String.new(message)
end
