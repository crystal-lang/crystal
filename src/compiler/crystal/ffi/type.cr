require "./ffi"

module Crystal::FFI
  struct Type
    def initialize(@type : LibFFI::Type*, @elements : Array(Type)? = nil)
      # TODO: we store @elements here to avoid the GC,
      # maybe that should be stored somewhere else.
      # But maybe libffi already dups these?
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

    def self.struct(elements : Array(Type))
      elements_ptr = Pointer(LibFFI::Type*).malloc(elements.size + 1)
      elements.each_with_index do |element, i|
        elements_ptr[i] = element.to_unsafe
      end
      elements_ptr[elements.size] = Pointer(LibFFI::Type).null

      pointer = Pointer(LibFFI::Type).malloc(1)
      pointer.value = LibFFI::Type.new(
        type: LibFFI::TypeEnum::STRUCT,
        elements: elements_ptr,
      )
      new(pointer, elements)
    end

    def inspect(io : IO)
      io << "FFI::Type("
      io << @type.value
      io << ")"
    end
  end
end
