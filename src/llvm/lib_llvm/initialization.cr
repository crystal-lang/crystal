{% skip_file unless LibLLVM::IS_LT_170 %}

require "./types"

lib LibLLVM
  fun initialize_core = LLVMInitializeCore(r : PassRegistryRef)
  fun initialize_transform_utils = LLVMInitializeTransformUtils(r : PassRegistryRef)
  fun initialize_scalar_opts = LLVMInitializeScalarOpts(r : PassRegistryRef)
  fun initialize_obj_c_arc_opts = LLVMInitializeObjCARCOpts(r : PassRegistryRef)
  fun initialize_vectorization = LLVMInitializeVectorization(r : PassRegistryRef)
  fun initialize_inst_combine = LLVMInitializeInstCombine(r : PassRegistryRef)
  fun initialize_ipo = LLVMInitializeIPO(r : PassRegistryRef)
  fun initialize_instrumentation = LLVMInitializeInstrumentation(r : PassRegistryRef)
  fun initialize_analysis = LLVMInitializeAnalysis(r : PassRegistryRef)
  fun initialize_ipa = LLVMInitializeIPA(r : PassRegistryRef)
  fun initialize_code_gen = LLVMInitializeCodeGen(r : PassRegistryRef)
  fun initialize_target = LLVMInitializeTarget(r : PassRegistryRef)
end
