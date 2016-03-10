struct LLVM::ParameterCollection
  @function : Function

  def initialize(@function)
  end

  def size
    LibLLVM.count_param_types(@function.function_type).to_i
  end

  def to_a
    param_size = size()
    Array(LLVM::Value).build(param_size) do |buffer|
      LibLLVM.get_params(@function, buffer as LibLLVM::ValueRef*)
      param_size
    end
  end

  def [](index)
    param_size = size()
    index += param_size if index < 0

    unless 0 <= index < param_size
      raise IndexError.new
    end

    Value.new LibLLVM.get_param(@function, index)
  end

  def first
    raise IndexError.new if size == 0

    Value.new LibLLVM.get_param(@function, 0)
  end

  def types
    param_size = size()
    Array(LLVM::Type).build(param_size) do |buffer|
      LibLLVM.get_param_types(@function.function_type, buffer as LibLLVM::TypeRef*)
      param_size
    end
  end
end
