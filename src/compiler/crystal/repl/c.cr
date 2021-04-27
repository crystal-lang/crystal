require "../types"
require "./value"

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

module Repl
  struct Value
    def ffi_value(pointer : Pointer(Void)) : Nil
      value = @value
      case value
      when Int8
        pointer.as(Int8*).value = value
      when UInt8
        pointer.as(UInt8*).value = value
      when Int16
        pointer.as(Int16*).value = value
      when UInt16
        pointer.as(UInt16*).value = value
      when Int32
        pointer.as(Int32*).value = value
      when UInt32
        pointer.as(UInt32*).value = value
      when Int64
        pointer.as(Int64*).value = value
      when UInt64
        pointer.as(UInt64*).value = value
      when Float32
        pointer.as(Float32*).value = value
      when Float64
        pointer.as(Float64*).value = value
      when String
        pointer.as(UInt8**).value = value.to_unsafe
      when PointerWrapper
        pointer.as(Void**).value = value.pointer
      else
        raise "BUG: missing ffi_value for #{self}"
      end
    end
  end
end
