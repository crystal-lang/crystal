{% skip_file if LibLLVM::IS_LT_130 %}

require "../target_machine"
require "../types"

lib LibLLVM
  type PassBuilderOptionsRef = Void*

  fun run_passes = LLVMRunPasses(m : ModuleRef, passes : Char*, tm : TargetMachineRef, options : PassBuilderOptionsRef) : ErrorRef

  fun create_pass_builder_options = LLVMCreatePassBuilderOptions : PassBuilderOptionsRef
  fun dispose_pass_builder_options = LLVMDisposePassBuilderOptions(options : PassBuilderOptionsRef)
  fun pass_builder_options_set_inliner_threshold = LLVMPassBuilderOptionsSetInlinerThreshold(PassBuilderOptionsRef, Int)
  fun pass_builder_options_set_loop_unrolling = LLVMPassBuilderOptionsSetLoopUnrolling(PassBuilderOptionsRef, Bool)
  fun pass_builder_options_set_loop_vectorization = LLVMPassBuilderOptionsSetLoopVectorization(PassBuilderOptionsRef, Bool)
  fun pass_builder_options_set_slp_vectorization = LLVMPassBuilderOptionsSetSLPVectorization(PassBuilderOptionsRef, Bool)
end
