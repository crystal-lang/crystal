class LLVM::MemoryBuffer
  def initialize(@unwrap : LibLLVM::MemoryBufferRef)
    @finalized = false
  end

  def to_slice
    Slice.new(
      LibLLVM.get_buffer_start(@unwrap),
      LibLLVM.get_buffer_size(@unwrap),
    )
  end

  def dispose
    return if @finalized
    @finalized = true
    finalize
  end

  def finalize
    return if @finalized

    LibLLVM.dispose_memory_buffer(@unwrap)
  end

  def to_unsafe
    @unwrap
  end
end
