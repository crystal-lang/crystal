require "./types"

lib LibLLVM
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(m : ModuleRef, path : Char*) : Int
  fun write_bitcode_to_fd = LLVMWriteBitcodeToFD(m : ModuleRef, fd : Int, should_close : Int, unbuffered : Int) : Int
  fun write_bitcode_to_memory_buffer = LLVMWriteBitcodeToMemoryBuffer(mod : ModuleRef) : MemoryBufferRef
end
