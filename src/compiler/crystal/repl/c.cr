require "../types"
require "./value"
require "./repl"

module Crystal
  class Type
    def ffi_type
      raise "BUG: missing ffi_type for #{self} (#{self.class})"
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
        raise "BUG: missing ffi_type for #{self} (#{self.class})"
      end
    end
  end

  class FloatType
    def ffi_type
      case kind
      when :f32 then FFI::Type.float
      when :f64 then FFI::Type.double
      else
        raise "BUG: missing ffi_type for #{self} (#{self.class})"
      end
    end
  end

  class EnumType
    def ffi_type
      base_type.ffi_type
    end
  end

  class PointerInstanceType
    def ffi_type
      FFI::Type.pointer
    end
  end

  class ProcInstanceType
    def ffi_type
      FFI::Type.pointer
    end

    def ffi_call_interface
      FFI::CallInterface.new(
        abi: FFI::ABI::DEFAULT,
        args: arg_types.map(&.ffi_type),
        return_type: return_type.ffi_type,
      )
    end
  end

  class NilType
    def ffi_type
      # Nil is used to pass a null pointer
      FFI::Type.pointer
    end
  end

  class NoReturnType
    def ffi_type
      FFI::Type.void
    end
  end

  class TypeDefType
    def ffi_type
      typedef.ffi_type
    end
  end

  class NonGenericClassType
    def ffi_type
      FFI::Type.struct(all_instance_vars.map do |name, var|
        var.type.ffi_type
      end)
    end
  end

  class StaticArrayInstanceType
    def ffi_type
      element_ffi_type = element_type.ffi_type
      FFI::Type.struct(
        Array.new(size.as(NumberLiteral).value.to_i, element_ffi_type)
      )
    end
  end
end

struct Crystal::Repl::Value
  def ffi_value(pointer : Pointer(Void)) : Nil
    pointer.as(Void**).value = @pointer
  end
end
