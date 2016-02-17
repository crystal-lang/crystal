struct LLVM::Type
  getter :unwrap

  def initialize(@unwrap)
  end

  def to_unsafe
    @unwrap
  end

  def self.void
    new LibLLVM.void_type
  end

  def self.int(bits)
    new LibLLVM.int_type(bits)
  end

  def self.float
    new LibLLVM.float_type
  end

  def self.double
    new LibLLVM.double_type
  end

  def self.pointer(element_type)
    new LibLLVM.pointer_type(element_type, 0)
  end

  def self.array(element_type, count)
    new LibLLVM.array_type(element_type, count)
  end

  def self.vector(element_type, count)
    new LibLLVM.vector_type(element_type, count)
  end

  def self.struct(name : String, packed = false)
    llvm_struct = LibLLVM.struct_create_named(Context.global, name)
    the_struct = new llvm_struct
    element_types = (yield the_struct) as Array(LLVM::Type)
    LibLLVM.struct_set_body(llvm_struct, (element_types.to_unsafe as LibLLVM::TypeRef*), element_types.size, packed ? 1 : 0)
    the_struct
  end

  def self.struct(element_types : Array(LLVM::Type), name = nil, packed = false)
    if name
      self.struct(name, packed) { element_types }
    else
      new LibLLVM.struct_type((element_types.to_unsafe as LibLLVM::TypeRef*), element_types.size, packed ? 1 : 0)
    end
  end

  def self.function(arg_types : Array(LLVM::Type), return_type, varargs = false)
    new LibLLVM.function_type(return_type, (arg_types.to_unsafe as LibLLVM::TypeRef*), arg_types.size, varargs ? 1 : 0)
  end

  def size
    # Asking the size of void crashes the program, we definitely don't want that
    if void?
      LLVM.int(LLVM::Int64, 1)
    else
      Value.new LibLLVM.size_of(self)
    end
  end

  def kind
    LibLLVM.get_type_kind(self)
  end

  def void?
    kind == Kind::Void
  end

  def null
    Value.new LibLLVM.const_null(self)
  end

  def null_pointer
    Value.new LibLLVM.const_pointer_null(self)
  end

  def undef
    Value.new LibLLVM.get_undef(self)
  end

  def pointer
    Type.pointer self
  end

  def array(count)
    Type.array self, count
  end

  def int_width
    raise "not an Integer" unless kind == Kind::Integer
    LibLLVM.get_int_type_width(self).to_i32
  end

  def packed_struct?
    raise "not a Struct" unless kind == Kind::Struct
    LibLLVM.is_packed_struct(self) != 0
  end

  def struct_element_types
    raise "not a Struct" unless kind == Kind::Struct
    count = LibLLVM.count_struct_element_types(self)

    Array(LLVM::Type).build(count) do |buffer|
      LibLLVM.get_struct_element_types(self, buffer as LibLLVM::TypeRef*)
      count
    end
  end

  def element_type
    case kind
    when Kind::Array, Kind::Vector, Kind::Pointer
      Type.new LibLLVM.get_element_type(self)
    else
      raise "not a sequential type"
    end
  end

  def array_size
    raise "not an Array" unless kind == Kind::Array
    LibLLVM.get_array_length(self).to_i32
  end

  def inspect(io)
    LLVM.to_io(LibLLVM.print_type_to_string(self), io)
    self
  end
end
