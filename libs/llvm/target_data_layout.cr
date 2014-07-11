struct LLVM::TargetDataLayout
  def initialize(@unwrap)
  end

  def size_in_bits(type)
    LibLLVM.size_of_type_in_bits(self, type)
  end

  def size_in_bytes(type)
    size_in_bits(type) / 8
  end

  def to_unsafe
    @unwrap
  end
end
