require "../types"
require "./value"
require "./repl"

# In this file we define how each Crystal type that can be passed to C
# is mapped to C for libffi.

module Crystal
  class Type
    # Must return an FFI::Type for this type.
    def ffi_type : FFI::Type
      raise "BUG: missing ffi_type for #{self} (#{self.class})"
    end

    # Returns an FFI::Type to be used as a C function argument.
    def ffi_arg_type : FFI::Type
      ffi_type
    end
  end

  class BoolType
    def ffi_type : FFI::Type
      FFI::Type.uint8
    end
  end

  class IntegerType
    def ffi_type : FFI::Type
      case kind
      when .i8?  then FFI::Type.sint8
      when .u8?  then FFI::Type.uint8
      when .i16? then FFI::Type.sint16
      when .u16? then FFI::Type.uint16
      when .i32? then FFI::Type.sint32
      when .u32? then FFI::Type.uint32
      when .i64? then FFI::Type.sint64
      when .u64? then FFI::Type.uint64
      else
        raise "BUG: missing ffi_type for #{self} (#{self.class})"
      end
    end
  end

  class FloatType
    def ffi_type : FFI::Type
      case kind
      when .f32? then FFI::Type.float
      when .f64? then FFI::Type.double
      else
        raise "BUG: missing ffi_type for #{self} (#{self.class})"
      end
    end
  end

  class EnumType
    def ffi_type : FFI::Type
      base_type.ffi_type
    end
  end

  class PointerInstanceType
    def ffi_type : FFI::Type
      FFI::Type.pointer
    end
  end

  class ProcInstanceType
    def ffi_type : FFI::Type
      FFI::Type.pointer
    end

    # Returns a FFI::CallInterface for this proc, suitable for calling it.
    getter(ffi_call_interface : FFI::CallInterface) do
      FFI::CallInterface.new(
        return_type.ffi_type,
        arg_types.map(&.ffi_arg_type)
      )
    end
  end

  class NilType
    def ffi_type : FFI::Type
      # Nil is used to pass a null pointer
      FFI::Type.pointer
    end
  end

  class NoReturnType
    def ffi_type : FFI::Type
      FFI::Type.void
    end
  end

  class TypeDefType
    def ffi_type : FFI::Type
      typedef.ffi_type
    end
  end

  class NonGenericClassType
    def ffi_type : FFI::Type
      FFI::Type.struct(all_instance_vars.map do |name, var|
        var.type.ffi_type
      end)
    end
  end

  class StaticArrayInstanceType
    def ffi_type : FFI::Type
      element_ffi_type = element_type.ffi_type
      FFI::Type.struct(
        Array.new(size.as(NumberLiteral).value.to_i, element_ffi_type)
      )
    end

    def ffi_arg_type : FFI::Type
      FFI::Type.pointer
    end
  end
end
