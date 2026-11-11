class LLVM::MemoryBuffer
  def self.from_file(filename : String)
    ret = LibLLVM.create_memory_buffer_with_contents_of_file(filename, out mem_buf, out msg)
    if ret != 0 && msg
      raise LLVM.string_and_dispose(msg)
    end
    new(mem_buf)
  end

  def initialize(@unwrap : LibLLVM::MemoryBufferRef)
    @dispose_on_finalize = true
  end

  def to_slice
    Slice.new(
      LibLLVM.get_buffer_start(@unwrap),
      LibLLVM.get_buffer_size(@unwrap),
    )
  end

  def dispose
    if @unwrap
      LibLLVM.dispose_memory_buffer(@unwrap)
      @unwrap = Pointer(Void).null.as(LibLLVM::MemoryBufferRef)
    end
  end

  def finalize
    dispose if @dispose_on_finalize
  end

  def to_unsafe
    @unwrap
  end

  def take_ownership(&) : Nil
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end
end
