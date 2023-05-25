require "./lib_llvm"
{% if flag?(:win32) %}
  @[Link(ldflags: "#{__DIR__}/ext/llvm_ext.obj")]
{% else %}
  @[Link(ldflags: "#{__DIR__}/ext/llvm_ext.o")]
{% end %}
lib LibLLVMExt
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt

  type OperandBundleDefRef = Void*

  {% if LibLLVM::IS_LT_90 %}
    fun di_builder_create_enumerator = LLVMExtDIBuilderCreateEnumerator(builder : LibLLVM::DIBuilderRef, name : Char*, value : Int64) : LibLLVM::MetadataRef
  {% end %}

  fun set_current_debug_location = LLVMExtSetCurrentDebugLocation(LibLLVM::BuilderRef, Int, Int, LibLLVM::MetadataRef, LibLLVM::MetadataRef)

  fun build_operand_bundle_def = LLVMExtBuildOperandBundleDef(name : LibC::Char*,
                                                              input : LibLLVM::ValueRef*,
                                                              num_input : LibC::UInt) : LibLLVMExt::OperandBundleDefRef

  fun build_call2 = LLVMExtBuildCall2(builder : LibLLVM::BuilderRef, ty : LibLLVM::TypeRef, fn : LibLLVM::ValueRef,
                                      args : LibLLVM::ValueRef*, arg_count : LibC::UInt,
                                      bundle : LibLLVMExt::OperandBundleDefRef,
                                      name : LibC::Char*) : LibLLVM::ValueRef

  fun build_invoke2 = LLVMExtBuildInvoke2(builder : LibLLVM::BuilderRef, ty : LibLLVM::TypeRef, fn : LibLLVM::ValueRef,
                                          args : LibLLVM::ValueRef*, arg_count : LibC::UInt,
                                          then : LibLLVM::BasicBlockRef, catch : LibLLVM::BasicBlockRef,
                                          bundle : LibLLVMExt::OperandBundleDefRef,
                                          name : LibC::Char*) : LibLLVM::ValueRef

  fun target_machine_enable_global_isel = LLVMExtTargetMachineEnableGlobalIsel(machine : LibLLVM::TargetMachineRef, enable : Bool)
  fun create_mc_jit_compiler_for_module = LLVMExtCreateMCJITCompilerForModule(jit : LibLLVM::ExecutionEngineRef*, m : LibLLVM::ModuleRef, options : LibLLVM::JITCompilerOptions*, options_length : UInt32, enable_global_isel : Bool, error : UInt8**) : Int32
end
