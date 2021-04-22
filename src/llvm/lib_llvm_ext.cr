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
  type Metadata = Void*
  type OperandBundleDefRef = Void*

  fun create_di_builder = LLVMExtNewDIBuilder(LibLLVM::ModuleRef) : DIBuilder
  fun di_builder_finalize = LLVMExtDIBuilderFinalize(DIBuilder)

  fun di_builder_create_function = LLVMExtDIBuilderCreateFunction(
    builder : DIBuilder, scope : Metadata, name : Char*,
    linkage_name : Char*, file : Metadata, line : UInt,
    composite_type : Metadata, is_local_to_unit : Bool, is_definition : Bool,
    scope_line : UInt, flags : LLVM::DIFlags, is_optimized : Bool, func : LibLLVM::ValueRef
  ) : Metadata

  fun di_builder_create_file = LLVMExtDIBuilderCreateFile(builder : DIBuilder, file : Char*, dir : Char*) : Metadata
  fun di_builder_create_compile_unit = LLVMExtDIBuilderCreateCompileUnit(builder : DIBuilder,
                                                                         lang : UInt, file : Char*,
                                                                         dir : Char*,
                                                                         producer : Char*,
                                                                         optimized : Int, flags : Char*,
                                                                         runtime_version : UInt) : Metadata
  fun di_builder_create_lexical_block = LLVMExtDIBuilderCreateLexicalBlock(builder : DIBuilder,
                                                                           scope : Metadata,
                                                                           file : Metadata,
                                                                           line : Int,
                                                                           column : Int) : Metadata

  fun di_builder_create_basic_type = LLVMExtDIBuilderCreateBasicType(builder : DIBuilder,
                                                                     name : Char*,
                                                                     size_in_bits : UInt64,
                                                                     align_in_bits : UInt64,
                                                                     encoding : UInt) : Metadata

  fun di_builder_create_auto_variable = LLVMExtDIBuilderCreateAutoVariable(builder : DIBuilder,
                                                                           scope : Metadata,
                                                                           name : Char*,
                                                                           file : Metadata, line : UInt,
                                                                           type : Metadata,
                                                                           always_preserve : Int,
                                                                           flags : LLVM::DIFlags,
                                                                           align_in_bits : UInt32) : Metadata

  fun di_builder_create_parameter_variable = LLVMExtDIBuilderCreateParameterVariable(builder : DIBuilder,
                                                                                     scope : Metadata,
                                                                                     name : Char*, arg_no : UInt,
                                                                                     file : Metadata, line : UInt, type : Metadata,
                                                                                     always_preserve : Int, flags : LLVM::DIFlags) : Metadata

  fun di_builder_insert_declare_at_end = LLVMExtDIBuilderInsertDeclareAtEnd(builder : DIBuilder,
                                                                            storage : LibLLVM::ValueRef,
                                                                            var_info : Metadata,
                                                                            expr : Metadata,
                                                                            dl : LibLLVM::ValueRef,
                                                                            block : LibLLVM::BasicBlockRef) : LibLLVM::ValueRef

  fun di_builder_create_expression = LLVMExtDIBuilderCreateExpression(builder : DIBuilder,
                                                                      addr : Int64*, length : SizeT) : Metadata

  fun di_builder_get_or_create_array = LLVMExtDIBuilderGetOrCreateArray(builder : DIBuilder, data : Metadata*, length : SizeT) : Metadata
  fun di_builder_create_enumerator = LLVMExtDIBuilderCreateEnumerator(builder : DIBuilder, name : Char*, value : Int64) : Metadata
  fun di_builder_create_enumeration_type = LLVMExtDIBuilderCreateEnumerationType(builder : DIBuilder,
                                                                                 scope : Metadata, name : Char*, file : Metadata, line_number : UInt,
                                                                                 size_in_bits : UInt64, align_in_bits : UInt64, elements : Metadata, underlying_type : Metadata) : Metadata

  fun di_builder_get_or_create_type_array = LLVMExtDIBuilderGetOrCreateTypeArray(builder : DIBuilder, data : Metadata*, length : SizeT) : Metadata
  fun di_builder_create_subroutine_type = LLVMExtDIBuilderCreateSubroutineType(builder : DIBuilder, file : Metadata, parameter_types : Metadata) : Metadata

  fun di_builder_create_struct_type = LLVMExtDIBuilderCreateStructType(builder : DIBuilder,
                                                                       scope : Metadata, name : Char*, file : Metadata, line : UInt, size_in_bits : UInt64,
                                                                       align_in_bits : UInt64, flags : LLVM::DIFlags, derived_from : Metadata, element_types : Metadata) : Metadata

  fun di_builder_create_union_type = LLVMExtDIBuilderCreateUnionType(builder : DIBuilder,
                                                                     scope : Metadata, name : Char*, file : Metadata, line : UInt, size_in_bits : UInt64,
                                                                     align_in_bits : UInt64, flags : LLVM::DIFlags, element_types : Metadata) : Metadata

  fun di_builder_create_array_type = LLVMExtDIBuilderCreateArrayType(builder : DIBuilder, size : UInt64,
                                                                     alignInBits : UInt32, ty : Metadata,
                                                                     subscripts : Metadata) : Metadata

  fun di_builder_create_member_type = LLVMExtDIBuilderCreateMemberType(builder : DIBuilder,
                                                                       scope : Metadata, name : Char*, file : Metadata, line : UInt, size_in_bits : UInt64,
                                                                       align_in_bits : UInt64, offset_in_bits : UInt64, flags : LLVM::DIFlags, ty : Metadata) : Metadata

  fun di_builder_create_pointer_type = LLVMExtDIBuilderCreatePointerType(builder : DIBuilder,
                                                                         pointee_type : Metadata,
                                                                         size_in_bits : UInt64,
                                                                         align_in_bits : UInt64,
                                                                         name : Char*) : Metadata

  fun di_builder_create_replaceable_composite_type = LLVMExtDIBuilderCreateReplaceableCompositeType(builder : DIBuilder,
                                                                                                    scope : Metadata,
                                                                                                    name : Char*,
                                                                                                    file : Metadata,
                                                                                                    line : UInt) : Metadata

  fun di_builder_create_unspecified_type = LLVMExtDIBuilderCreateUnspecifiedType(builder : LibLLVMExt::DIBuilder,
                                                                                 name : Void*,
                                                                                 size : LibC::SizeT) : LibLLVMExt::Metadata

  fun di_builder_create_lexical_block_file = LLVMExtDIBuilderCreateLexicalBlockFile(builder : LibLLVMExt::DIBuilder,
                                                                                    scope : LibLLVMExt::Metadata,
                                                                                    file_scope : LibLLVMExt::Metadata,
                                                                                    discriminator : UInt32) : LibLLVMExt::Metadata

  fun di_builder_replace_temporary = LLVMExtDIBuilderReplaceTemporary(builder : DIBuilder, from : Metadata, to : Metadata)

  fun set_current_debug_location = LLVMExtSetCurrentDebugLocation(LibLLVM::BuilderRef, Int, Int, Metadata, Metadata)

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

  {% unless LibLLVM::IS_38 || LibLLVM::IS_39 %}
    fun write_bitcode_with_summary_to_file = LLVMExtWriteBitcodeWithSummaryToFile(module : LibLLVM::ModuleRef, path : UInt8*) : Void
  {% end %}

  fun normalize_target_triple = LLVMExtNormalizeTargetTriple(triple : Char*) : Char*
  fun basic_block_name = LLVMExtBasicBlockName(basic_block : LibLLVM::BasicBlockRef) : Char*
  fun di_builder_get_or_create_array_subrange = LLVMExtDIBuilderGetOrCreateArraySubrange(builder : DIBuilder, lo : UInt64, count : UInt64) : Metadata

  fun target_machine_enable_global_isel = LLVMExtTargetMachineEnableGlobalIsel(machine : LibLLVM::TargetMachineRef, enable : Bool)
  fun create_mc_jit_compiler_for_module = LLVMExtCreateMCJITCompilerForModule(jit : LibLLVM::ExecutionEngineRef*, m : LibLLVM::ModuleRef, options : LibLLVM::JITCompilerOptions*, options_length : UInt32, enable_global_isel : Bool, error : UInt8**) : Int32
end
