{% skip_file if LibLLVM::IS_LT_110 %}

lib LibLLVM
  # OrcJITTargetAddress before LLVM 13.0 (also an alias of UInt64)
  alias OrcExecutorAddress = UInt64

  alias OrcJITDylibRef = Void*
  alias OrcThreadSafeContextRef = Void*
  alias OrcThreadSafeModuleRef = Void*

  fun orc_create_new_thread_safe_context = LLVMOrcCreateNewThreadSafeContext : OrcThreadSafeContextRef
  fun orc_thread_safe_context_get_context = LLVMOrcThreadSafeContextGetContext(ts_ctx : OrcThreadSafeContextRef) : ContextRef
  fun orc_dispose_thread_safe_context = LLVMOrcDisposeThreadSafeContext(ts_ctx : OrcThreadSafeContextRef)

  fun orc_create_new_thread_safe_module = LLVMOrcCreateNewThreadSafeModule(m : ModuleRef, ts_ctx : OrcThreadSafeContextRef) : OrcThreadSafeModuleRef
  fun orc_dispose_thread_safe_module = LLVMOrcDisposeThreadSafeModule(tsm : OrcThreadSafeModuleRef)
end
