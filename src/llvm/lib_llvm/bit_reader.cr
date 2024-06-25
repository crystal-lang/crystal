require "./types"

lib LibLLVM
  fun parse_bitcode_in_context2 = LLVMParseBitcodeInContext2(c : ContextRef, mb : MemoryBufferRef, m : ModuleRef*) : Int
end
