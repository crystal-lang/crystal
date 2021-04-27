require "../types"
require "./value"
require "./repl"

module Crystal
  class Type
    def ffi_type
      raise "BUG: missing ffi_type for #{self}"
    end
  end

  class IntegerType
    def ffi_type
      case kind
      when :i8  then FFI::Type.sint8
      when :u8  then FFI::Type.uint8
      when :i16 then FFI::Type.sint16
      when :u16 then FFI::Type.uint16
      when :i32 then FFI::Type.sint32
      when :u32 then FFI::Type.uint32
      when :i64 then FFI::Type.sint64
      when :u64 then FFI::Type.uint64
      when :f32 then FFI::Type.float
      when :f64 then FFI::Type.double
      else
        raise "BUG: missing ffi_type for #{self}"
      end
    end
  end

  class NoReturnType
    def ffi_type
      FFI::Type.void
    end
  end
end

struct Crystal::Repl::Value
  def ffi_value(pointer : Pointer(Void)) : Nil
    pointer.as(Void**).value = @pointer
  end
end
