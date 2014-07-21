struct LLVM::Function
  getter :unwrap

  def initialize(@unwrap)
  end

  def dump
    LLVM.dump self
  end

  def append_basic_block(name)
    LibLLVM.append_basic_block(self, name)
  end

  def append_basic_block(name)
    block = append_basic_block(name)
    builder = Builder.new
    builder.position_at_end block
    yield builder
    block
  end

  def name
    String.new LibLLVM.get_value_name(self)
  end

  def get_param(index)
    LibLLVM.get_param(self, index)
  end

  def linkage=(linkage)
    LibLLVM.set_linkage(self, linkage)
  end

  def add_attribute(attribute)
    LibLLVM.add_function_attr self, attribute
  end

  def function_type
    LibLLVM.get_element_type(LLVM.type_of(self))
  end

  def return_type
    LibLLVM.get_return_type(function_type)
  end

  def param_count
    LibLLVM.count_param_types(function_type).to_i
  end

  def params
    Array(LibLLVM::ValueRef).new(param_count) { |i| get_param(i) }
  end

  def param_types
    type = function_type
    param_count = LibLLVM.count_param_types(type)
    param_types = Pointer(LibLLVM::TypeRef).malloc(param_count)
    LibLLVM.get_param_types(type, param_types)
    param_types.as_enumerable(param_count.to_i).to_a
  end

  def varargs?
    LibLLVM.is_function_var_arg(function_type) != 0
  end

  def to_unsafe
    @unwrap
  end
end
