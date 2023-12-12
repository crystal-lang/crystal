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
    fun clear_current_debug_location = LLVMExtClearCurrentDebugLocation(b : LibLLVM::BuilderRef)
  {% end %}

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

  fun set_target_machine_global_isel = LLVMExtSetTargetMachineGlobalISel(t : LibLLVM::TargetMachineRef, enable : LibLLVM::Bool)
end
