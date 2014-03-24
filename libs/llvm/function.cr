require "wrapper"

struct LLVM::Function
  include LLVM::Wrapper

  getter :fun

  def initialize(@fun)
  end

  def wrapped_pointer
    @fun
  end

  def dump
    LLVM.dump @fun
  end

  def append_basic_block(name)
    LibLLVM.append_basic_block(@fun, name)
  end

  def append_basic_block(name)
    block = append_basic_block(name)
    builder = Builder.new
    builder.position_at_end block
    yield builder
    block
  end

  def dump
    LLVM.dump @fun
  end

  def llvm_function
    @fun
  end

  def get_param(index)
    LibLLVM.get_param(@fun, index)
  end

  def linkage=(linkage)
    LibLLVM.set_linkage(@fun, linkage)
  end

  def add_attribute(attribute)
    LibLLVM.add_function_attr @fun, attribute
  end

  def function_type
    LibLLVM.get_element_type(LLVM.type_of(@fun))
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
    param_types.to_a(param_count.to_i)
  end

  def varargs?
    LibLLVM.is_function_var_arg(function_type) != 0
  end
end
