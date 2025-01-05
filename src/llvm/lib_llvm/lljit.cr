{% skip_file if LibLLVM::IS_LT_110 %}

lib LibLLVM
  alias OrcLLJITBuilderRef = Void*
  alias OrcLLJITRef = Void*

  fun orc_create_lljit_builder = LLVMOrcCreateLLJITBuilder : OrcLLJITBuilderRef
  fun orc_dispose_lljit_builder = LLVMOrcDisposeLLJITBuilder(builder : OrcLLJITBuilderRef)

  fun orc_create_lljit = LLVMOrcCreateLLJIT(result : OrcLLJITRef*, builder : OrcLLJITBuilderRef) : ErrorRef
  fun orc_dispose_lljit = LLVMOrcDisposeLLJIT(j : OrcLLJITRef) : ErrorRef

  fun orc_lljit_get_main_jit_dylib = LLVMOrcLLJITGetMainJITDylib(j : OrcLLJITRef) : OrcJITDylibRef
  fun orc_lljit_get_global_prefix = LLVMOrcLLJITGetGlobalPrefix(j : OrcLLJITRef) : Char
  fun orc_lljit_add_llvm_ir_module = LLVMOrcLLJITAddLLVMIRModule(j : OrcLLJITRef, jd : OrcJITDylibRef, tsm : OrcThreadSafeModuleRef) : ErrorRef
  fun orc_lljit_lookup = LLVMOrcLLJITLookup(j : OrcLLJITRef, result : OrcExecutorAddress*, name : Char*) : ErrorRef
end
