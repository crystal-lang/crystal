require "./types"

lib LibLLVM
  enum DWARFEmissionKind
    Full = 1
  end

  fun create_di_builder = LLVMCreateDIBuilder(m : ModuleRef) : DIBuilderRef
  fun dispose_di_builder = LLVMDisposeDIBuilder(builder : DIBuilderRef)
  fun di_builder_finalize = LLVMDIBuilderFinalize(builder : DIBuilderRef)

  {% if LibLLVM::IS_LT_110 %}
    fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(
      builder : DIBuilderRef, lang : LLVM::DwarfSourceLanguage, file_ref : MetadataRef, producer : Char*,
      producer_len : SizeT, is_optimized : Bool, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
      split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
      split_debug_inlining : Bool, debug_info_for_profiling : Bool
    ) : MetadataRef
  {% else %}
    fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(
      builder : DIBuilderRef, lang : LLVM::DwarfSourceLanguage, file_ref : MetadataRef, producer : Char*,
      producer_len : SizeT, is_optimized : Bool, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
      split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
      split_debug_inlining : Bool, debug_info_for_profiling : Bool, sys_root : Char*,
      sys_root_len : SizeT, sdk : Char*, sdk_len : SizeT
    ) : MetadataRef
  {% end %}

  fun di_builder_create_file = LLVMDIBuilderCreateFile(
    builder : DIBuilderRef, filename : Char*, filename_len : SizeT,
    directory : Char*, directory_len : SizeT
  ) : MetadataRef

  fun di_builder_create_function = LLVMDIBuilderCreateFunction(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
    linkage_name : Char*, linkage_name_len : SizeT, file : MetadataRef, line_no : UInt,
    ty : MetadataRef, is_local_to_unit : Bool, is_definition : Bool, scope_line : UInt,
    flags : LLVM::DIFlags, is_optimized : Bool
  ) : MetadataRef

  fun di_builder_create_lexical_block = LLVMDIBuilderCreateLexicalBlock(
    builder : DIBuilderRef, scope : MetadataRef, file : MetadataRef, line : UInt, column : UInt
  ) : MetadataRef
  fun di_builder_create_lexical_block_file = LLVMDIBuilderCreateLexicalBlockFile(
    builder : DIBuilderRef, scope : MetadataRef, file_scope : MetadataRef, discriminator : UInt
  ) : MetadataRef

  fun di_builder_create_debug_location = LLVMDIBuilderCreateDebugLocation(
    ctx : ContextRef, line : UInt, column : UInt, scope : MetadataRef, inlined_at : MetadataRef
  ) : MetadataRef

  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilderRef, types : MetadataRef*, length : SizeT) : MetadataRef

  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(
    builder : DIBuilderRef, file : MetadataRef, parameter_types : MetadataRef*,
    num_parameter_types : UInt, flags : LLVM::DIFlags
  ) : MetadataRef
  {% unless LibLLVM::IS_LT_90 %}
    fun di_builder_create_enumerator = LLVMDIBuilderCreateEnumerator(
      builder : DIBuilderRef, name : Char*, name_len : SizeT, value : Int64, is_unsigned : Bool
    ) : MetadataRef
  {% end %}
  fun di_builder_create_enumeration_type = LLVMDIBuilderCreateEnumerationType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    elements : MetadataRef*, num_elements : UInt, class_ty : MetadataRef
  ) : MetadataRef
  fun di_builder_create_union_type = LLVMDIBuilderCreateUnionType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVM::DIFlags,
    elements : MetadataRef*, num_elements : UInt, run_time_lang : UInt, unique_id : Char*, unique_id_len : SizeT
  ) : MetadataRef
  fun di_builder_create_array_type = LLVMDIBuilderCreateArrayType(
    builder : DIBuilderRef, size : UInt64, align_in_bits : UInt32,
    ty : MetadataRef, subscripts : MetadataRef*, num_subscripts : UInt
  ) : MetadataRef
  fun di_builder_create_unspecified_type = LLVMDIBuilderCreateUnspecifiedType(builder : DIBuilderRef, name : Char*, name_len : SizeT) : MetadataRef
  fun di_builder_create_basic_type = LLVMDIBuilderCreateBasicType(
    builder : DIBuilderRef, name : Char*, name_len : SizeT, size_in_bits : UInt64,
    encoding : UInt, flags : LLVM::DIFlags
  ) : MetadataRef
  fun di_builder_create_pointer_type = LLVMDIBuilderCreatePointerType(
    builder : DIBuilderRef, pointee_ty : MetadataRef, size_in_bits : UInt64, align_in_bits : UInt32,
    address_space : UInt, name : Char*, name_len : SizeT
  ) : MetadataRef
  fun di_builder_create_struct_type = LLVMDIBuilderCreateStructType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVM::DIFlags,
    derived_from : MetadataRef, elements : MetadataRef*, num_elements : UInt,
    run_time_lang : UInt, v_table_holder : MetadataRef, unique_id : Char*, unique_id_len : SizeT
  ) : MetadataRef
  fun di_builder_create_member_type = LLVMDIBuilderCreateMemberType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, size_in_bits : UInt64, align_in_bits : UInt32, offset_in_bits : UInt64,
    flags : LLVM::DIFlags, ty : MetadataRef
  ) : MetadataRef
  fun di_builder_create_replaceable_composite_type = LLVMDIBuilderCreateReplaceableCompositeType(
    builder : DIBuilderRef, tag : UInt, name : Char*, name_len : SizeT, scope : MetadataRef,
    file : MetadataRef, line : UInt, runtime_lang : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    flags : LLVM::DIFlags, unique_identifier : Char*, unique_identifier_len : SizeT
  ) : MetadataRef

  fun di_builder_get_or_create_subrange = LLVMDIBuilderGetOrCreateSubrange(builder : DIBuilderRef, lo : Int64, count : Int64) : MetadataRef
  fun di_builder_get_or_create_array = LLVMDIBuilderGetOrCreateArray(builder : DIBuilderRef, data : MetadataRef*, length : SizeT) : MetadataRef

  {% if LibLLVM::IS_LT_140 %}
    fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : Int64*, length : SizeT) : MetadataRef
  {% else %}
    fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : UInt64*, length : SizeT) : MetadataRef
  {% end %}

  fun metadata_replace_all_uses_with = LLVMMetadataReplaceAllUsesWith(target_metadata : MetadataRef, replacement : MetadataRef)

  fun di_builder_insert_declare_at_end = LLVMDIBuilderInsertDeclareAtEnd(
    builder : DIBuilderRef, storage : ValueRef, var_info : MetadataRef,
    expr : MetadataRef, debug_loc : MetadataRef, block : BasicBlockRef
  ) : ValueRef

  fun di_builder_create_auto_variable = LLVMDIBuilderCreateAutoVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, ty : MetadataRef, always_preserve : Bool, flags : LLVM::DIFlags, align_in_bits : UInt32
  ) : MetadataRef
  fun di_builder_create_parameter_variable = LLVMDIBuilderCreateParameterVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, arg_no : UInt,
    file : MetadataRef, line_no : UInt, ty : MetadataRef, always_preserve : Bool, flags : LLVM::DIFlags
  ) : MetadataRef

  fun set_subprogram = LLVMSetSubprogram(func : ValueRef, sp : MetadataRef)
end
