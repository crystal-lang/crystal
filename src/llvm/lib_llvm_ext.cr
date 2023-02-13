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

  type DIBuilder = Void*
  type OperandBundleDefRef = Void*

  fun create_di_builder = LLVMExtNewDIBuilder(LibLLVM::ModuleRef) : DIBuilder
  fun di_builder_finalize = LLVMDIBuilderFinalize(DIBuilder)

  fun di_builder_create_function = LLVMExtDIBuilderCreateFunction(
    builder : DIBuilder, scope : LibLLVM::MetadataRef, name : Char*,
    linkage_name : Char*, file : LibLLVM::MetadataRef, line : UInt,
    composite_type : LibLLVM::MetadataRef, is_local_to_unit : Bool, is_definition : Bool,
    scope_line : UInt, flags : LLVM::DIFlags, is_optimized : Bool, func : LibLLVM::ValueRef
  ) : LibLLVM::MetadataRef

  fun di_builder_create_file = LLVMExtDIBuilderCreateFile(builder : DIBuilder, file : Char*, dir : Char*) : LibLLVM::MetadataRef
  fun di_builder_create_compile_unit = LLVMExtDIBuilderCreateCompileUnit(builder : DIBuilder,
                                                                         lang : UInt, file : Char*,
                                                                         dir : Char*,
                                                                         producer : Char*,
                                                                         optimized : Int, flags : Char*,
                                                                         runtime_version : UInt) : LibLLVM::MetadataRef
  fun di_builder_create_lexical_block = LLVMExtDIBuilderCreateLexicalBlock(builder : DIBuilder,
                                                                           scope : LibLLVM::MetadataRef,
                                                                           file : LibLLVM::MetadataRef,
                                                                           line : Int,
                                                                           column : Int) : LibLLVM::MetadataRef

  fun di_builder_create_basic_type = LLVMExtDIBuilderCreateBasicType(builder : DIBuilder,
                                                                     name : Char*,
                                                                     size_in_bits : UInt64,
                                                                     align_in_bits : UInt64,
                                                                     encoding : UInt) : LibLLVM::MetadataRef

  fun di_builder_create_auto_variable = LLVMExtDIBuilderCreateAutoVariable(builder : DIBuilder,
                                                                           scope : LibLLVM::MetadataRef,
                                                                           name : Char*,
                                                                           file : LibLLVM::MetadataRef, line : UInt,
                                                                           type : LibLLVM::MetadataRef,
                                                                           always_preserve : Int,
                                                                           flags : LLVM::DIFlags,
                                                                           align_in_bits : UInt32) : LibLLVM::MetadataRef

  fun di_builder_create_parameter_variable = LLVMExtDIBuilderCreateParameterVariable(builder : DIBuilder,
                                                                                     scope : LibLLVM::MetadataRef,
                                                                                     name : Char*, arg_no : UInt,
                                                                                     file : LibLLVM::MetadataRef, line : UInt, type : LibLLVM::MetadataRef,
                                                                                     always_preserve : Int, flags : LLVM::DIFlags) : LibLLVM::MetadataRef

  fun di_builder_insert_declare_at_end = LLVMExtDIBuilderInsertDeclareAtEnd(builder : DIBuilder,
                                                                            storage : LibLLVM::ValueRef,
                                                                            var_info : LibLLVM::MetadataRef,
                                                                            expr : LibLLVM::MetadataRef,
                                                                            dl : LibLLVM::ValueRef,
                                                                            block : LibLLVM::BasicBlockRef) : LibLLVM::ValueRef

  fun di_builder_create_expression = LLVMExtDIBuilderCreateExpression(builder : DIBuilder,
                                                                      addr : UInt64*, length : SizeT) : LibLLVM::MetadataRef

  fun di_builder_get_or_create_array = LLVMExtDIBuilderGetOrCreateArray(builder : DIBuilder, data : LibLLVM::MetadataRef*, length : SizeT) : LibLLVM::MetadataRef
  fun di_builder_create_enumerator = LLVMExtDIBuilderCreateEnumerator(builder : DIBuilder, name : Char*, value : Int64) : LibLLVM::MetadataRef
  fun di_builder_create_enumeration_type = LLVMExtDIBuilderCreateEnumerationType(builder : DIBuilder,
                                                                                 scope : LibLLVM::MetadataRef, name : Char*, file : LibLLVM::MetadataRef, line_number : UInt,
                                                                                 size_in_bits : UInt64, align_in_bits : UInt64, elements : LibLLVM::MetadataRef, underlying_type : LibLLVM::MetadataRef) : LibLLVM::MetadataRef

  fun di_builder_get_or_create_type_array = LLVMExtDIBuilderGetOrCreateTypeArray(builder : DIBuilder, data : LibLLVM::MetadataRef*, length : SizeT) : LibLLVM::MetadataRef
  fun di_builder_create_subroutine_type = LLVMExtDIBuilderCreateSubroutineType(builder : DIBuilder, file : LibLLVM::MetadataRef, parameter_types : LibLLVM::MetadataRef) : LibLLVM::MetadataRef

  fun di_builder_create_struct_type = LLVMExtDIBuilderCreateStructType(builder : DIBuilder,
                                                                       scope : LibLLVM::MetadataRef, name : Char*, file : LibLLVM::MetadataRef, line : UInt, size_in_bits : UInt64,
                                                                       align_in_bits : UInt64, flags : LLVM::DIFlags, derived_from : LibLLVM::MetadataRef, element_types : LibLLVM::MetadataRef) : LibLLVM::MetadataRef

  fun di_builder_create_union_type = LLVMExtDIBuilderCreateUnionType(builder : DIBuilder,
                                                                     scope : LibLLVM::MetadataRef, name : Char*, file : LibLLVM::MetadataRef, line : UInt, size_in_bits : UInt64,
                                                                     align_in_bits : UInt64, flags : LLVM::DIFlags, element_types : LibLLVM::MetadataRef) : LibLLVM::MetadataRef

  fun di_builder_create_array_type = LLVMExtDIBuilderCreateArrayType(builder : DIBuilder, size : UInt64,
                                                                     alignInBits : UInt64, ty : LibLLVM::MetadataRef,
                                                                     subscripts : LibLLVM::MetadataRef) : LibLLVM::MetadataRef

  fun di_builder_create_member_type = LLVMExtDIBuilderCreateMemberType(builder : DIBuilder,
                                                                       scope : LibLLVM::MetadataRef, name : Char*, file : LibLLVM::MetadataRef, line : UInt, size_in_bits : UInt64,
                                                                       align_in_bits : UInt64, offset_in_bits : UInt64, flags : LLVM::DIFlags, ty : LibLLVM::MetadataRef) : LibLLVM::MetadataRef

  fun di_builder_create_pointer_type = LLVMExtDIBuilderCreatePointerType(builder : DIBuilder,
                                                                         pointee_type : LibLLVM::MetadataRef,
                                                                         size_in_bits : UInt64,
                                                                         align_in_bits : UInt64,
                                                                         name : Char*) : LibLLVM::MetadataRef

  fun di_builder_create_replaceable_composite_type = LLVMExtDIBuilderCreateReplaceableCompositeType(builder : DIBuilder,
                                                                                                    scope : LibLLVM::MetadataRef,
                                                                                                    name : Char*,
                                                                                                    file : LibLLVM::MetadataRef,
                                                                                                    line : UInt) : LibLLVM::MetadataRef

  fun di_builder_create_unspecified_type = LLVMDIBuilderCreateUnspecifiedType(builder : LibLLVMExt::DIBuilder,
                                                                              name : Void*,
                                                                              size : LibC::SizeT) : LibLLVM::MetadataRef

  fun di_builder_create_lexical_block_file = LLVMDIBuilderCreateLexicalBlockFile(builder : LibLLVMExt::DIBuilder,
                                                                                 scope : LibLLVM::MetadataRef,
                                                                                 file_scope : LibLLVM::MetadataRef,
                                                                                 discriminator : UInt32) : LibLLVM::MetadataRef

  fun di_builder_replace_temporary = LLVMExtDIBuilderReplaceTemporary(builder : DIBuilder, from : LibLLVM::MetadataRef, to : LibLLVM::MetadataRef)

  fun set_current_debug_location = LLVMExtSetCurrentDebugLocation(LibLLVM::BuilderRef, Int, Int, LibLLVM::MetadataRef, LibLLVM::MetadataRef)

  fun build_cmpxchg = LLVMExtBuildCmpxchg(builder : LibLLVM::BuilderRef, pointer : LibLLVM::ValueRef, cmp : LibLLVM::ValueRef, new : LibLLVM::ValueRef, success_ordering : LLVM::AtomicOrdering, failure_ordering : LLVM::AtomicOrdering) : LibLLVM::ValueRef
  fun set_ordering = LLVMExtSetOrdering(value : LibLLVM::ValueRef, ordering : LLVM::AtomicOrdering)

  fun build_catch_pad = LLVMExtBuildCatchPad(builder : LibLLVM::BuilderRef,
                                             parent_pad : LibLLVM::ValueRef,
                                             arg_count : LibC::UInt,
                                             args : LibLLVM::ValueRef*,
                                             name : LibC::Char*) : LibLLVM::ValueRef

  fun build_catch_ret = LLVMExtBuildCatchRet(builder : LibLLVM::BuilderRef,
                                             pad : LibLLVM::ValueRef,
                                             basic_block : LibLLVM::BasicBlockRef) : LibLLVM::ValueRef

  fun build_catch_switch = LLVMExtBuildCatchSwitch(builder : LibLLVM::BuilderRef,
                                                   parent_pad : LibLLVM::ValueRef,
                                                   basic_block : LibLLVM::BasicBlockRef,
                                                   num_handlers : LibC::UInt,
                                                   name : LibC::Char*) : LibLLVM::ValueRef

  fun add_handler = LLVMExtAddHandler(catch_switch_ref : LibLLVM::ValueRef,
                                      handler : LibLLVM::BasicBlockRef) : Void

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

  fun write_bitcode_with_summary_to_file = LLVMExtWriteBitcodeWithSummaryToFile(module : LibLLVM::ModuleRef, path : UInt8*) : Void

  fun normalize_target_triple = LLVMExtNormalizeTargetTriple(triple : Char*) : Char*
  fun di_builder_get_or_create_array_subrange = LLVMExtDIBuilderGetOrCreateArraySubrange(builder : DIBuilder, lo : UInt64, count : UInt64) : LibLLVM::MetadataRef

  fun target_machine_enable_global_isel = LLVMExtTargetMachineEnableGlobalIsel(machine : LibLLVM::TargetMachineRef, enable : Bool)
  fun create_mc_jit_compiler_for_module = LLVMExtCreateMCJITCompilerForModule(jit : LibLLVM::ExecutionEngineRef*, m : LibLLVM::ModuleRef, options : LibLLVM::JITCompilerOptions*, options_length : UInt32, enable_global_isel : Bool, error : UInt8**) : Int32

  # LLVMCreateTypeAttribute is implemented in LLVM 13, but needed in 12
  {% if LibLLVM::IS_LT_130 %}
    fun create_type_attribute = LLVMExtCreateTypeAttribute(ctx : LibLLVM::ContextRef, kind_id : LibC::UInt, ty : LibLLVM::TypeRef) : LibLLVM::AttributeRef
  {% else %}
    fun create_type_attribute = LLVMCreateTypeAttribute(ctx : LibLLVM::ContextRef, kind_id : LibC::UInt, ty : LibLLVM::TypeRef) : LibLLVM::AttributeRef
  {% end %}
end
