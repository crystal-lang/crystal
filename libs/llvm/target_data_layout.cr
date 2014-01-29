class LLVM::TargetDataLayout
  def initialize(@target_data)
  end

  def size_in_bits(type)
    LibLLVM.size_of_type_in_bits(@target_data, type)
  end

  def size_in_bytes(type)
    size_in_bits(type) / 8
  end
end
