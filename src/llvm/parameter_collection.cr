struct LLVM::ParameterCollection
  def initialize(@function)
  end

  def count
    LibLLVM.count_param_types(@function.function_type).to_i
  end

  def length
    count
  end

  def size
    count
  end

  def to_a
    param_count = count()
    Array(LLVM::Value).build(param_count) do |buffer|
      LibLLVM.get_params(@function, buffer as LibLLVM::ValueRef*)
      param_count
    end
  end

  def [](index)
    param_count = count()
    index += param_count if index < 0

    unless 0 <= index < param_count
      raise IndexOutOfBounds.new
    end

    Value.new LibLLVM.get_param(@function, index)
  end

  def first
    raise IndexOutOfBounds.new if count == 0

    Value.new LibLLVM.get_param(@function, 0)
  end

  def types
    param_count = count()
    Array(LLVM::Type).build(param_count) do |buffer|
      LibLLVM.get_param_types(@function.function_type, buffer as LibLLVM::TypeRef*)
      param_count
    end
  end
end
