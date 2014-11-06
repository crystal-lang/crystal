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
    new LibLLVM.pointer_type(element_type, 0_u32)
  end

  def self.array(element_type, count)
    new LibLLVM.array_type(element_type, count.to_u32)
  end

  def self.struct(name : String, packed = false)
    llvm_struct = LibLLVM.struct_create_named(Context.global, name)
    the_struct = new llvm_struct
    element_types = (yield the_struct) as Array(LLVM::Type)
    LibLLVM.struct_set_body(llvm_struct, (element_types.buffer as LibLLVM::TypeRef*), element_types.length.to_u32, packed ? 1 : 0)
    the_struct
  end

  def self.struct(element_types : Array(LLVM::Type), name = nil, packed = false)
    if name
      self.struct(name, packed) { element_types }
    else
      new LibLLVM.struct_type((element_types.buffer as LibLLVM::TypeRef*), element_types.length.to_u32, packed ? 1 : 0)
    end
  end

  def self.function(arg_types : Array(LLVM::Type), return_type, varargs = false)
    new LibLLVM.function_type(return_type, (arg_types.buffer as LibLLVM::TypeRef*), arg_types.length.to_u32, varargs ? 1 : 0)
  end

  def size
    Value.new LibLLVM.size_of(self)
  end

  def kind
    Kind.new LibLLVM.get_type_kind(self)
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

  def inspect(io)
    LLVM.to_io(LibLLVM.print_type_to_string(self), io)
    self
  end
end
