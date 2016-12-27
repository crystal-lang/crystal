require "./lib_llvm"
@[Link(ldflags: "#{__DIR__}/ext/llvm_ext.o")]
lib LibLLVMExt
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias SizeT = LibC::SizeT

  type DIBuilder = Void*
  type Metadata = Void*

  fun create_di_builder = LLVMNewDIBuilder(LibLLVM::ModuleRef) : DIBuilder
  fun di_builder_finalize = LLVMDIBuilderFinalize(DIBuilder)

  {% if LibLLVM::IS_36 || LibLLVM::IS_35 %}
    fun di_builder_create_function = LLVMDIBuilderCreateFunction(
                                                                 builder : DIBuilder, scope : Metadata, name : Char*,
                                                                 linkage_name : Char*, file : Metadata, line : UInt,
                                                                 composite_type : Metadata, is_local_to_unit : Int, is_definition : Int,
                                                                 scope_line : UInt, flags : LLVM::DIFlags, is_optimized : Int, func : LibLLVM::ValueRef) : Metadata
  {% else %}
    fun di_builder_create_function = LLVMDIBuilderCreateFunction(
                                                                 builder : DIBuilder, scope : Metadata, name : Char*,
                                                                 linkage_name : Char*, file : Metadata, line : UInt,
                                                                 composite_type : Metadata, is_local_to_unit : Bool, is_definition : Bool,
                                                                 scope_line : UInt, flags : LLVM::DIFlags, is_optimized : Bool, func : LibLLVM::ValueRef) : Metadata
  {% end %}

  fun di_builder_create_file = LLVMDIBuilderCreateFile(builder : DIBuilder, file : Char*, dir : Char*) : Metadata
  fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(builder : DIBuilder,
                                                                      lang : UInt, file : Char*,
                                                                      dir : Char*,
                                                                      producer : Char*,
                                                                      optimized : Int, flags : Char*,
                                                                      runtime_version : UInt) : Metadata
  fun di_builder_create_lexical_block = LLVMDIBuilderCreateLexicalBlock(builder : DIBuilder,
                                                                        scope : Metadata,
                                                                        file : Metadata,
                                                                        line : Int,
                                                                        column : Int) : Metadata

  fun di_builder_create_basic_type = LLVMDIBuilderCreateBasicType(builder : DIBuilder,
                                                                  name : Char*,
                                                                  size_in_bits : UInt64,
                                                                  align_in_bits : UInt64,
                                                                  encoding : UInt) : Metadata

  fun di_builder_create_auto_variable = LLVMDIBuilderCreateAutoVariable(builder : DIBuilder,
                                                                        scope : Metadata,
                                                                        name : Char*,
                                                                        file : Metadata, line : UInt,
                                                                        type : Metadata,
                                                                        always_preserve : Int,
                                                                        flags : LLVM::DIFlags,
                                                                        align_in_bits : UInt32) : Metadata

  fun di_builder_create_parameter_variable = LLVMDIBuilderCreateParameterVariable(builder : DIBuilder,
                                                                                  scope : Metadata,
                                                                                  name : Char*, arg_no : UInt,
                                                                                  file : Metadata, line : UInt, type : Metadata,
                                                                                  always_preserve : Int, flags : LLVM::DIFlags) : Metadata

  fun di_builder_insert_declare_at_end = LLVMDIBuilderInsertDeclareAtEnd(builder : DIBuilder,
                                                                         storage : LibLLVM::ValueRef,
                                                                         var_info : Metadata,
                                                                         expr : Metadata,
                                                                         dl : LibLLVM::ValueRef,
                                                                         block : LibLLVM::BasicBlockRef) : LibLLVM::ValueRef

  fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilder,
                                                                   addr : Int64*, length : SizeT) : Metadata

  fun di_builder_get_or_create_array = LLVMDIBuilderGetOrCreateArray(builder : DIBuilder, data : Metadata*, length : SizeT) : Metadata
  fun di_builder_create_enumerator = LLVMDIBuilderCreateEnumerator(builder : DIBuilder, name : Char*, value : Int64) : Metadata
  fun di_builder_create_enumeration_type = LLVMDIBuilderCreateEnumerationType(builder : DIBuilder,
                                                                              scope : Metadata, name : Char*, file : Metadata, line_number : UInt,
                                                                              size_in_bits : UInt64, align_in_bits : UInt64, elements : Metadata, underlying_type : Metadata) : Metadata

  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilder, data : Metadata*, length : SizeT) : Metadata
  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(builder : DIBuilder, file : Metadata, parameter_types : Metadata) : Metadata

  fun di_builder_create_struct_type = LLVMDIBuilderCreateStructType(builder : DIBuilder,
                                                                    scope : Metadata, name : Char*, file : Metadata, line : UInt, size_in_bits : UInt64,
                                                                    align_in_bits : UInt64, flags : LLVM::DIFlags, derived_from : Metadata, element_types : Metadata) : Metadata

  fun di_builder_create_member_type = LLVMDIBuilderCreateMemberType(builder : DIBuilder,
                                                                    scope : Metadata, name : Char*, file : Metadata, line : UInt, size_in_bits : UInt64,
                                                                    align_in_bits : UInt64, offset_in_bits : UInt64, flags : LLVM::DIFlags, ty : Metadata) : Metadata

  fun di_builder_create_pointer_type = LLVMDIBuilderCreatePointerType(builder : DIBuilder,
                                                                      pointee_type : Metadata,
                                                                      size_in_bits : UInt64,
                                                                      align_in_bits : UInt64,
                                                                      name : Char*) : Metadata

  {% if LibLLVM::IS_35 || LibLLVM::IS_36 %}
    fun temporary_md_node = LLVMTemporaryMDNode(context : LibLLVM::ContextRef, mds : Metadata*, count : UInt) : Metadata
    fun metadata_replace_all_uses_with = LLVMMetadataReplaceAllUsesWith(Metadata, Metadata)
  {% else %}
    fun di_builder_create_replaceable_composite_type = LLVMDIBuilderCreateReplaceableCompositeType(builder : DIBuilder,
                                                                                                   scope : Metadata,
                                                                                                   name : Char*,
                                                                                                                    file : Metadata,
                                                                                                   line : UInt) : Metadata
    fun di_builder_replace_temporary = LLVMDIBuilderReplaceTemporary(builder : DIBuilder, from : Metadata, to : Metadata)
  {% end %}

  fun set_current_debug_location = LLVMSetCurrentDebugLocation2(LibLLVM::BuilderRef, Int, Int, Metadata, Metadata)

  fun build_cmpxchg = LLVMExtBuildCmpxchg(builder : LibLLVM::BuilderRef, pointer : LibLLVM::ValueRef, cmp : LibLLVM::ValueRef, new : LibLLVM::ValueRef, success_ordering : LLVM::AtomicOrdering, failure_ordering : LLVM::AtomicOrdering) : LibLLVM::ValueRef
  fun set_ordering = LLVMExtSetOrdering(value : LibLLVM::ValueRef, ordering : LLVM::AtomicOrdering)
end
