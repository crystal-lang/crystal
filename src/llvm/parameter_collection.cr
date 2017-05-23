struct LLVM::ParameterCollection
  def initialize(@function : Function)
  end

  def size
    @function.function_type.params_size
  end

  def to_a
    param_size = size()
    Array(LLVM::Value).build(param_size) do |buffer|
      LibLLVM.get_params(@function, buffer.as(LibLLVM::ValueRef*))
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
    @function.function_type.params_types
  end
end
