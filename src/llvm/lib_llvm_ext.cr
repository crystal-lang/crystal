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
  alias SizeT = LibC::SizeT

  {% if LibLLVM::IS_LT_90 %}
    fun di_builder_create_enumerator = LLVMExtDIBuilderCreateEnumerator(builder : LibLLVM::DIBuilderRef, name : Char*, value : Int64) : LibLLVM::MetadataRef
    fun clear_current_debug_location = LLVMExtClearCurrentDebugLocation(b : LibLLVM::BuilderRef)
  {% end %}

  fun create_operand_bundle = LLVMExtCreateOperandBundle(tag : Char*, tag_len : SizeT,
                                                         args : LibLLVM::ValueRef*,
                                                         num_args : UInt) : LibLLVM::OperandBundleRef

  fun build_call_with_operand_bundles = LLVMExtBuildCallWithOperandBundles(LibLLVM::BuilderRef, LibLLVM::TypeRef, fn : LibLLVM::ValueRef,
                                                                           args : LibLLVM::ValueRef*, num_args : UInt,
                                                                           bundles : LibLLVM::OperandBundleRef*, num_bundles : UInt,
                                                                           name : Char*) : LibLLVM::ValueRef

  fun build_invoke_with_operand_bundles = LLVMExtBuildInvokeWithOperandBundles(LibLLVM::BuilderRef, ty : LibLLVM::TypeRef, fn : LibLLVM::ValueRef,
                                                                               args : LibLLVM::ValueRef*, num_args : UInt,
                                                                               then : LibLLVM::BasicBlockRef, catch : LibLLVM::BasicBlockRef,
                                                                               bundles : LibLLVM::OperandBundleRef*, num_bundles : UInt,
                                                                               name : Char*) : LibLLVM::ValueRef

  fun target_machine_enable_global_isel = LLVMExtTargetMachineEnableGlobalIsel(machine : LibLLVM::TargetMachineRef, enable : Bool)
end
