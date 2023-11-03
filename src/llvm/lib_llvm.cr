{% begin %}
lib LibLLVM
  LLVM_CONFIG = {{ env("LLVM_CONFIG") || `#{__DIR__}/ext/find-llvm-config`.stringify }}
end
{% end %}

{% begin %}
  {% unless flag?(:win32) %}
    @[Link("stdc++")]
  {% end %}
  @[Link(ldflags: {{"`#{LibLLVM::LLVM_CONFIG} --libs --system-libs --ldflags#{" --link-static".id if flag?(:static)}#{" 2> /dev/null".id unless flag?(:win32)}`"}})]
  lib LibLLVM
    VERSION = {{`#{LibLLVM::LLVM_CONFIG} --version`.chomp.stringify.gsub(/git/, "")}}
    BUILT_TARGETS = {{ (
                         env("LLVM_TARGETS") || `#{LibLLVM::LLVM_CONFIG} --targets-built`
                       ).strip.downcase.split(' ').map(&.id.symbolize) }}
  end
{% end %}

{% begin %}
  lib LibLLVM
    IS_170 = {{LibLLVM::VERSION.starts_with?("17.0")}}
    IS_160 = {{LibLLVM::VERSION.starts_with?("16.0")}}
    IS_150 = {{LibLLVM::VERSION.starts_with?("15.0")}}
    IS_140 = {{LibLLVM::VERSION.starts_with?("14.0")}}
    IS_130 = {{LibLLVM::VERSION.starts_with?("13.0")}}
    IS_120 = {{LibLLVM::VERSION.starts_with?("12.0")}}
    IS_111 = {{LibLLVM::VERSION.starts_with?("11.1")}}
    IS_110 = {{LibLLVM::VERSION.starts_with?("11.0")}}
    IS_100 = {{LibLLVM::VERSION.starts_with?("10.0")}}
    IS_90 = {{LibLLVM::VERSION.starts_with?("9.0")}}
    IS_80 = {{LibLLVM::VERSION.starts_with?("8.0")}}

    IS_LT_90 = {{compare_versions(LibLLVM::VERSION, "9.0.0") < 0}}
    IS_LT_100 = {{compare_versions(LibLLVM::VERSION, "10.0.0") < 0}}
    IS_LT_110 = {{compare_versions(LibLLVM::VERSION, "11.0.0") < 0}}
    IS_LT_120 = {{compare_versions(LibLLVM::VERSION, "12.0.0") < 0}}
    IS_LT_130 = {{compare_versions(LibLLVM::VERSION, "13.0.0") < 0}}
    IS_LT_140 = {{compare_versions(LibLLVM::VERSION, "14.0.0") < 0}}
    IS_LT_150 = {{compare_versions(LibLLVM::VERSION, "15.0.0") < 0}}
    IS_LT_160 = {{compare_versions(LibLLVM::VERSION, "16.0.0") < 0}}
    IS_LT_170 = {{compare_versions(LibLLVM::VERSION, "17.0.0") < 0}}
  end
{% end %}

lib LibLLVM
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias LongLong = LibC::LongLong
  alias ULongLong = LibC::ULongLong
  alias Double = LibC::Double
  alias SizeT = LibC::SizeT
end

require "./lib_llvm/**"

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
      producer_len : SizeT, is_optimized : Int, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
      split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
      split_debug_inlining : Int, debug_info_for_profiling : Int
    ) : MetadataRef
  {% else %}
    fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(
      builder : DIBuilderRef, lang : LLVM::DwarfSourceLanguage, file_ref : MetadataRef, producer : Char*,
      producer_len : SizeT, is_optimized : Int, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
      split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
      split_debug_inlining : Int, debug_info_for_profiling : Int, sys_root : Char*,
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
    ty : MetadataRef, is_local_to_unit : Int, is_definition : Int, scope_line : UInt,
    flags : LLVM::DIFlags, is_optimized : Int
  ) : MetadataRef

  fun di_builder_create_lexical_block = LLVMDIBuilderCreateLexicalBlock(
    builder : DIBuilderRef, scope : MetadataRef, file : MetadataRef, line : UInt, column : UInt
  ) : MetadataRef
  fun di_builder_create_lexical_block_file = LLVMDIBuilderCreateLexicalBlockFile(
    builder : DIBuilderRef, scope : MetadataRef, file_scope : MetadataRef, discriminator : UInt
  ) : MetadataRef

  {% unless LibLLVM::IS_LT_90 %}
    fun di_builder_create_enumerator = LLVMDIBuilderCreateEnumerator(
      builder : DIBuilderRef, name : Char*, name_len : SizeT, value : Int64, is_unsigned : Int
    ) : MetadataRef
  {% end %}

  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(
    builder : DIBuilderRef, file : MetadataRef, parameter_types : MetadataRef*,
    num_parameter_types : UInt, flags : LLVM::DIFlags
  ) : MetadataRef
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
  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilderRef, types : MetadataRef*, length : SizeT) : MetadataRef

  {% if LibLLVM::IS_LT_140 %}
    fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : Int64*, length : SizeT) : MetadataRef
  {% else %}
    fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : UInt64*, length : SizeT) : MetadataRef
  {% end %}

  fun di_builder_insert_declare_at_end = LLVMDIBuilderInsertDeclareAtEnd(
    builder : DIBuilderRef, storage : ValueRef, var_info : MetadataRef,
    expr : MetadataRef, debug_loc : MetadataRef, block : BasicBlockRef
  ) : ValueRef

  fun di_builder_create_auto_variable = LLVMDIBuilderCreateAutoVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, ty : MetadataRef, always_preserve : Int, flags : LLVM::DIFlags, align_in_bits : UInt32
  ) : MetadataRef
  fun di_builder_create_parameter_variable = LLVMDIBuilderCreateParameterVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, arg_no : UInt,
    file : MetadataRef, line_no : UInt, ty : MetadataRef, always_preserve : Int, flags : LLVM::DIFlags
  ) : MetadataRef

  fun set_subprogram = LLVMSetSubprogram(func : ValueRef, sp : MetadataRef)
  fun metadata_replace_all_uses_with = LLVMMetadataReplaceAllUsesWith(target_metadata : MetadataRef, replacement : MetadataRef)
end
