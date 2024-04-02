require "./target"
require "./target_machine"
require "./types"

lib LibLLVM
  fun link_in_mc_jit = LLVMLinkInMCJIT

  type GenericValueRef = Void*
  type ExecutionEngineRef = Void*
  type MCJITMemoryManagerRef = Void*

  struct MCJITCompilerOptions
    opt_level : UInt
    code_model : LLVM::CodeModel
    no_frame_pointer_elim : Bool
    enable_fast_isel : Bool
    mcjmm : MCJITMemoryManagerRef
  end

  fun create_generic_value_of_int = LLVMCreateGenericValueOfInt(ty : TypeRef, n : ULongLong, is_signed : Bool) : GenericValueRef
  fun create_generic_value_of_pointer = LLVMCreateGenericValueOfPointer(p : Void*) : GenericValueRef
  fun generic_value_to_int = LLVMGenericValueToInt(gen_val : GenericValueRef, is_signed : Bool) : ULongLong
  fun generic_value_to_pointer = LLVMGenericValueToPointer(gen_val : GenericValueRef) : Void*
  fun generic_value_to_float = LLVMGenericValueToFloat(ty_ref : TypeRef, gen_val : GenericValueRef) : Double
  fun dispose_generic_value = LLVMDisposeGenericValue(gen_val : GenericValueRef)

  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule(out_jit : ExecutionEngineRef*, m : ModuleRef, opt_level : UInt, error : Char**) : Bool
  fun create_mc_jit_compiler_for_module = LLVMCreateMCJITCompilerForModule(out_jit : ExecutionEngineRef*, m : ModuleRef, options : MCJITCompilerOptions*, size_of_options : SizeT, out_error : Char**) : Bool
  fun dispose_execution_engine = LLVMDisposeExecutionEngine(ee : ExecutionEngineRef)
  fun run_function = LLVMRunFunction(ee : ExecutionEngineRef, f : ValueRef, num_args : UInt, args : GenericValueRef*) : GenericValueRef
  fun get_execution_engine_target_machine = LLVMGetExecutionEngineTargetMachine(ee : ExecutionEngineRef) : TargetMachineRef
  fun get_pointer_to_global = LLVMGetPointerToGlobal(ee : ExecutionEngineRef, global : ValueRef) : Void*
end
