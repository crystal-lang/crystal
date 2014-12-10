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
    null_value = LLVM::Value.new(Pointer(Void).null as LibLLVM::ValueRef)
    ary = Array(LLVM::Value).new(param_count, null_value)
    LibLLVM.get_params(@function, ary.buffer as LibLLVM::ValueRef*)
    ary
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
    null_type = LLVM::Type.new(Pointer(Void).null as LibLLVM::TypeRef)
    ary = Array(LLVM::Type).new(param_count, null_type)
    LibLLVM.get_param_types(@function.function_type, ary.buffer as LibLLVM::TypeRef*)
    ary
  end
end
