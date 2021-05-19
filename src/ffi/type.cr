require "./ffi"

module FFI
  struct Type
    def initialize(@type : LibFFI::Type*)
    end

    def to_unsafe
      @type
    end

    def self.void
      new(pointerof(LibFFI.ffi_type_void))
    end

    def self.uint8
      new(pointerof(LibFFI.ffi_type_uint8))
    end

    def self.sint8
      new(pointerof(LibFFI.ffi_type_sint8))
    end

    def self.uint16
      new(pointerof(LibFFI.ffi_type_uint16))
    end

    def self.sint16
      new(pointerof(LibFFI.ffi_type_sint16))
    end

    def self.uint32
      new(pointerof(LibFFI.ffi_type_uint32))
    end

    def self.sint32
      new(pointerof(LibFFI.ffi_type_sint32))
    end

    def self.uint64
      new(pointerof(LibFFI.ffi_type_uint64))
    end

    def self.sint64
      new(pointerof(LibFFI.ffi_type_sint64))
    end

    def self.float
      new(pointerof(LibFFI.ffi_type_float))
    end

    def self.double
      new(pointerof(LibFFI.ffi_type_double))
    end

    def self.pointer
      new(pointerof(LibFFI.ffi_type_pointer))
    end
  end
end
