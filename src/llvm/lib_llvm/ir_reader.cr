require "./types"

lib LibLLVM
  fun parse_ir_in_context = LLVMParseIRInContext(context_ref : ContextRef, mem_buf : MemoryBufferRef, out_m : ModuleRef*, out_message : Char**) : Bool
end
