class LLVM::MemoryBuffer
  def self.from_file(filename : String)
    ret = LibLLVM.create_memory_buffer_with_contents_of_file(filename, out mem_buf, out msg)
    if ret != 0 && msg
      raise LLVM.string_and_dispose(msg)
    end
    new(mem_buf)
  end

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
