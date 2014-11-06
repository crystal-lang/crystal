require "value_methods"

struct LLVM::Function
  include LLVM::ValueMethods

  def basic_blocks
    BasicBlockCollection.new self
  end

  def call_convention
    LLVM::CallConvention.new LibLLVM.get_function_call_convention(self)
  end

  def call_convention=(cc)
    LibLLVM.set_function_call_convention(self, cc)
  end

  def add_attribute(attribute)
    LibLLVM.add_function_attr self, attribute.value
  end

  def attributes
    Attribute.new LibLLVM.get_function_attr(self)
  end

  def function_type
    Type.new LibLLVM.get_element_type(LibLLVM.type_of(self))
  end

  def return_type
    Type.new LibLLVM.get_return_type(function_type)
  end

  def varargs?
    LibLLVM.is_function_var_arg(function_type) != 0
  end

  def params
    ParameterCollection.new self
  end
end
