{% skip_file unless LibLLVM::IS_LT_170 %}

require "../types"

lib LibLLVM
  type PassManagerBuilderRef = Void*

  fun pass_manager_builder_create = LLVMPassManagerBuilderCreate : PassManagerBuilderRef
  fun dispose_pass_manager_builder = LLVMPassManagerBuilderDispose(pmb : PassManagerBuilderRef)
  fun pass_manager_builder_set_opt_level = LLVMPassManagerBuilderSetOptLevel(pmb : PassManagerBuilderRef, opt_level : UInt)
  fun pass_manager_builder_set_size_level = LLVMPassManagerBuilderSetSizeLevel(pmb : PassManagerBuilderRef, size_level : UInt)
  fun pass_manager_builder_set_disable_unroll_loops = LLVMPassManagerBuilderSetDisableUnrollLoops(pmb : PassManagerBuilderRef, value : Bool)
  fun pass_manager_builder_set_disable_simplify_lib_calls = LLVMPassManagerBuilderSetDisableSimplifyLibCalls(pmb : PassManagerBuilderRef, value : Bool)
  fun pass_manager_builder_use_inliner_with_threshold = LLVMPassManagerBuilderUseInlinerWithThreshold(pmb : PassManagerBuilderRef, threshold : UInt)
  fun pass_manager_builder_populate_function_pass_manager = LLVMPassManagerBuilderPopulateFunctionPassManager(pmb : PassManagerBuilderRef, pm : PassManagerRef)
  fun pass_manager_builder_populate_module_pass_manager = LLVMPassManagerBuilderPopulateModulePassManager(pmb : PassManagerBuilderRef, pm : PassManagerRef)
end
