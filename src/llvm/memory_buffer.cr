class LLVM::MemoryBuffer
  def initialize(@unwrap : LibLLVM::MemoryBufferRef | Bytes)
    @finalized = false
  end

  def to_slice
    if (unwrap = @unwrap).is_a?(Bytes)
      unwrap
    else
      Slice.new(
        LibLLVM.get_buffer_start(unwrap),
        LibLLVM.get_buffer_size(unwrap),
      )
    end
  end

  def dispose
    return if @finalized
    @finalized = true
    finalize
  end

  def finalize
    return if @finalized

    if (unwrap = @unwrap).is_a?(LibLLVM::MemoryBufferRef)
      LibLLVM.dispose_memory_buffer(unwrap)
    end
  end

  def to_unsafe
    @unwrap
  end
end
