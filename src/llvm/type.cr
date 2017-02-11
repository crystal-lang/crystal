struct LLVM::Type
  getter unwrap : LibLLVM::TypeRef

  def initialize(@unwrap : LibLLVM::TypeRef)
  end

  def to_unsafe
    @unwrap
  end

  def self.void : self
    new LibLLVM.void_type
  end

  def self.int(bits) : self
    new LibLLVM.int_type(bits)
  end

  def self.float : self
    new LibLLVM.float_type
  end

  def self.double : self
    new LibLLVM.double_type
  end

  def self.pointer(element_type) : self
    new LibLLVM.pointer_type(element_type, 0)
  end

  def self.array(element_type, count) : self
    new LibLLVM.array_type(element_type, count)
  end

  def self.vector(element_type, count) : self
    new LibLLVM.vector_type(element_type, count)
  end

  def self.struct(name : String, packed = false) : self
    Context.global.struct(name, packed) do |str|
      yield str
    end
  end

  def self.struct(element_types : Array(LLVM::Type), name = nil, packed = false) : self
    if name
      self.struct(name, packed) { element_types }
    else
      new LibLLVM.struct_type((element_types.to_unsafe.as(LibLLVM::TypeRef*)), element_types.size, packed ? 1 : 0)
    end
  end

  def self.function(arg_types : Array(LLVM::Type), return_type, varargs = false) : self
    new LibLLVM.function_type(return_type, (arg_types.to_unsafe.as(LibLLVM::TypeRef*)), arg_types.size, varargs ? 1 : 0)
  end

  def size
    # Asking the size of void crashes the program, we definitely don't want that
    if void?
      LLVM::Int64.const_int(1)
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
      LibLLVM.get_struct_element_types(self, buffer.as(LibLLVM::TypeRef*))
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

  def const_int(value) : Value
    Value.new LibLLVM.const_int(self, value, 0)
  end

  def const_float(value : Float32) : Value
    Value.new LibLLVM.const_real(self, value)
  end

  def const_float(value : String) : Value
    Value.new LibLLVM.const_real_of_string(self, value)
  end

  def const_double(value : Float64) : Value
    Value.new LibLLVM.const_real(self, value)
  end

  def const_double(string : String) : Value
    Value.new LibLLVM.const_real_of_string(self, string)
  end

  def const_array(values : Array(LLVM::Value)) : Value
    Value.new LibLLVM.const_array(self, (values.to_unsafe.as(LibLLVM::ValueRef*)), values.size)
  end

  def const_inline_asm(asm_string, constraints, has_side_effects = false, is_align_stack = false)
    Value.new LibLLVM.const_inline_asm(self, asm_string, constraints, (has_side_effects ? 1 : 0), (is_align_stack ? 1 : 0))
  end

  def context : Context
    Context.new(LibLLVM.get_type_context(self), dispose_on_finalize: false)
  end

  def inspect(io)
    LLVM.to_io(LibLLVM.print_type_to_string(self), io)
    self
  end
end
