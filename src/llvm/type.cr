struct LLVM::Type
  getter unwrap : LibLLVM::TypeRef

  def initialize(@unwrap : LibLLVM::TypeRef)
  end

  def to_unsafe
    @unwrap
  end

  def self.function(arg_types : Array(LLVM::Type), return_type, varargs = false) : self
    new LibLLVM.function_type(return_type, (arg_types.to_unsafe.as(LibLLVM::TypeRef*)), arg_types.size, varargs ? 1 : 0)
  end

  def size
    # Asking the size of void crashes the program, we definitely don't want that
    if void?
      context.int64.const_int(1)
    else
      Value.new LibLLVM.size_of(self)
    end
  end

  def kind : LLVM::Type::Kind
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

  def pointer : LLVM::Type
    {% if LibLLVM::IS_LT_150 %}
      Type.new LibLLVM.pointer_type(self, 0)
    {% else %}
      Type.new LibLLVM.pointer_type_in_context(LibLLVM.get_type_context(self), 0)
    {% end %}
  end

  def array(count) : LLVM::Type
    Type.new LibLLVM.array_type(self, count)
  end

  def vector(count) : self
    Type.new LibLLVM.vector_type(self, count)
  end

  def int_width : Int32
    raise "Not an Integer" unless kind == Kind::Integer
    LibLLVM.get_int_type_width(self).to_i32
  end

  def packed_struct? : Bool
    raise "Not a Struct" unless kind == Kind::Struct
    LibLLVM.is_packed_struct(self) != 0
  end

  # Assuming this type is a struct, returns its name.
  # The name can be `nil` if the struct is anonymous.
  # Raises if this type is not a struct.
  def struct_name : String?
    raise "Not a Struct" unless kind == Kind::Struct

    name = LibLLVM.get_struct_name(self)
    name ? String.new(name) : nil
  end

  def struct_element_types : Array(LLVM::Type)
    raise "Not a Struct" unless kind == Kind::Struct
    count = LibLLVM.count_struct_element_types(self)

    Array(LLVM::Type).build(count) do |buffer|
      LibLLVM.get_struct_element_types(self, buffer.as(LibLLVM::TypeRef*))
      count
    end
  end

  def element_type : LLVM::Type
    case kind
    when Kind::Array, Kind::Vector
      Type.new LibLLVM.get_element_type(self)
    when Kind::Pointer
      {% if LibLLVM::IS_LT_150 %}
        Type.new LibLLVM.get_element_type(self)
      {% else %}
        raise "Typed pointers are unavailable on LLVM 15.0 or above"
      {% end %}
    else
      raise "Not a sequential type"
    end
  end

  def array_size : Int32
    raise "Not an Array" unless kind == Kind::Array
    LibLLVM.get_array_length(self).to_i32
  end

  def vector_size
    raise "Not a Vector" unless kind == Kind::Vector
    LibLLVM.get_vector_size(self).to_i32
  end

  def return_type
    raise "Not a Function" unless kind == Kind::Function
    Type.new LibLLVM.get_return_type(self)
  end

  def params_types
    params_size = self.params_size
    Array(LLVM::Type).build(params_size) do |buffer|
      LibLLVM.get_param_types(self, buffer.as(LibLLVM::TypeRef*))
      params_size
    end
  end

  def params_size
    raise "Not a Function" unless kind == Kind::Function
    LibLLVM.count_param_types(self).to_i
  end

  def varargs?
    raise "Not a Function" unless kind == Kind::Function
    LibLLVM.is_function_var_arg(self) != 0
  end

  def const_int(value) : Value
    if !value.is_a?(Int128) && !value.is_a?(UInt128) && int_width != 128
      Value.new LibLLVM.const_int(self, value, 0)
    else
      encoded_value = UInt64[value & UInt64::MAX, (value >> 64) & UInt64::MAX]
      Value.new LibLLVM.const_int_of_arbitrary_precision(self, encoded_value.size, encoded_value)
    end
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

  def inline_asm(asm_string, constraints, has_side_effects = false, is_align_stack = false, can_throw = false)
    value =
      {% if LibLLVM::IS_LT_130 %}
        LibLLVM.get_inline_asm(
          self,
          asm_string,
          asm_string.size,
          constraints,
          constraints.size,
          (has_side_effects ? 1 : 0),
          (is_align_stack ? 1 : 0),
          LibLLVM::InlineAsmDialect::ATT
        )
      {% else %}
        LibLLVM.get_inline_asm(
          self,
          asm_string,
          asm_string.size,
          constraints,
          constraints.size,
          (has_side_effects ? 1 : 0),
          (is_align_stack ? 1 : 0),
          LibLLVM::InlineAsmDialect::ATT,
          (can_throw ? 1 : 0)
        )
      {% end %}
    Value.new value
  end

  def context : Context
    Context.new(LibLLVM.get_type_context(self), dispose_on_finalize: false)
  end

  def inspect(io : IO) : Nil
    LLVM.to_io(LibLLVM.print_type_to_string(self), io)
    self
  end
end
