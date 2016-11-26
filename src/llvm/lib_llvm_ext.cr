require "./lib_llvm"
@[Link(ldflags: "#{__DIR__}/ext/llvm_ext.o")]
lib LibLLVMExt
  type DIBuilder = Void*
  type Metadata = Void*

  fun create_di_builder = LLVMNewDIBuilder(LibLLVM::ModuleRef) : DIBuilder
  fun di_builder_finalize = LLVMDIBuilderFinalize(DIBuilder)

  {% if LibLLVM::IS_36 || LibLLVM::IS_35 %}
    fun di_builder_create_function = LLVMDIBuilderCreateFunction(
                                                                 builder : DIBuilder, scope : Metadata, name : LibC::Char*,
                                                                 linkage_name : LibC::Char*, file : Metadata, line : LibC::UInt,
                                                                 composite_type : Metadata, is_local_to_unit : LibC::Int, is_definition : LibC::Int,
                                                                 scope_line : LibC::UInt, flags : LibC::UInt, is_optimized : LibC::Int, func : LibLLVM::ValueRef) : Metadata
  {% else %}
    fun di_builder_create_function = LLVMDIBuilderCreateFunction(
                                                                 builder : DIBuilder, scope : Metadata, name : LibC::Char*,
                                                                 linkage_name : LibC::Char*, file : Metadata, line : LibC::UInt,
                                                                 composite_type : Metadata, is_local_to_unit : Bool, is_definition : Bool,
                                                                 scope_line : LibC::UInt, flags : LibC::UInt, is_optimized : Bool, func : LibLLVM::ValueRef) : Metadata
  {% end %}

  fun di_builder_create_file = LLVMDIBuilderCreateFile(builder : DIBuilder, file : LibC::Char*, dir : LibC::Char*) : Metadata
  fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(builder : DIBuilder,
                                                                      lang : LibC::UInt, file : LibC::Char*,
                                                                      dir : LibC::Char*,
                                                                      producer : LibC::Char*,
                                                                      optimized : LibC::Int, flags : LibC::Char*,
                                                                      runtime_version : LibC::UInt) : Metadata
  fun di_builder_create_lexical_block = LLVMDIBuilderCreateLexicalBlock(builder : DIBuilder,
                                                                        scope : Metadata,
                                                                        file : Metadata,
                                                                        line : LibC::Int,
                                                                        column : LibC::Int) : Metadata

  fun di_builder_create_basic_type = LLVMDIBuilderCreateBasicType(builder : DIBuilder,
                                                                  name : LibC::Char*,
                                                                  size_in_bits : UInt64,
                                                                  align_in_bits : UInt64,
                                                                  encoding : LibC::UInt) : Metadata

  fun di_builder_create_auto_variable = LLVMDIBuilderCreateAutoVariable(builder : DIBuilder,
                                                                        scope : Metadata,
                                                                        name : LibC::Char*,
                                                                        file : Metadata, line : LibC::UInt,
                                                                        type : Metadata,
                                                                        always_preserve : LibC::Int, flags : LibC::UInt) : Metadata

  fun di_builder_create_parameter_variable = LLVMDIBuilderCreateParameterVariable(builder : DIBuilder,
                                                                                  scope : Metadata,
                                                                                  name : LibC::Char*, arg_no : LibC::UInt,
                                                                                  file : Metadata, line : LibC::UInt, type : Metadata,
                                                                                  always_preserve : LibC::Int, flags : LibC::UInt) : Metadata

  fun di_builder_insert_declare_at_end = LLVMDIBuilderInsertDeclareAtEnd(builder : DIBuilder,
                                                                         storage : LibLLVM::ValueRef,
                                                                         var_info : Metadata,
                                                                         expr : Metadata,
                                                                         dl : LibLLVM::ValueRef,
                                                                         block : LibLLVM::BasicBlockRef) : LibLLVM::ValueRef

  fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilder,
                                                                   addr : Int64*, length : LibC::SizeT) : Metadata

  fun di_builder_get_or_create_array = LLVMDIBuilderGetOrCreateArray(builder : DIBuilder, data : Metadata*, length : LibC::SizeT) : Metadata
  fun di_builder_create_enumerator = LLVMDIBuilderCreateEnumerator(builder : DIBuilder, name : LibC::Char*, value : Int64) : Metadata
  fun di_builder_create_enumeration_type = LLVMDIBuilderCreateEnumerationType(builder : DIBuilder,
                                                                              scope : Metadata, name : LibC::Char*, file : Metadata, line_number : LibC::UInt,
                                                                              size_in_bits : UInt64, align_in_bits : UInt64, elements : Metadata, underlying_type : Metadata) : Metadata

  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilder, data : Metadata*, length : LibC::SizeT) : Metadata
  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(builder : DIBuilder, file : Metadata, parameter_types : Metadata) : Metadata

  fun di_builder_create_struct_type = LLVMDIBuilderCreateStructType(builder : DIBuilder,
                                                                    scope : Metadata, name : LibC::Char*, file : Metadata, line : LibC::UInt, size_in_bits : UInt64,
                                                                    align_in_bits : UInt64, flags : LibC::UInt, derived_from : Metadata, element_types : Metadata) : Metadata

  fun di_builder_create_member_type = LLVMDIBuilderCreateMemberType(builder : DIBuilder,
                                                                    scope : Metadata, name : LibC::Char*, file : Metadata, line : LibC::UInt, size_in_bits : UInt64,
                                                                    align_in_bits : UInt64, offset_in_bits : UInt64, flags : LibC::UInt, ty : Metadata) : Metadata

  fun di_builder_create_pointer_type = LLVMDIBuilderCreatePointerType(builder : DIBuilder,
                                                                      pointee_type : Metadata,
                                                                      size_in_bits : UInt64,
                                                                      align_in_bits : UInt64,
                                                                      name : LibC::Char*) : Metadata

  {% if LibLLVM::IS_35 || LibLLVM::IS_36 %}
    fun temporary_md_node = LLVMTemporaryMDNode(context : LibLLVM::ContextRef, mds : Metadata*, count : LibC::UInt) : Metadata
    fun metadata_replace_all_uses_with = LLVMMetadataReplaceAllUsesWith(Metadata, Metadata)
  {% else %}
    fun di_builder_create_replaceable_composite_type = LLVMDIBuilderCreateReplaceableCompositeType(builder : DIBuilder,
                                                                                                   scope : Metadata,
                                                                                                   name : LibC::Char*,
                                                                                                                    file : Metadata,
                                                                                                   line : LibC::UInt) : Metadata
    fun di_builder_replace_temporary = LLVMDIBuilderReplaceTemporary(builder : DIBuilder, from : Metadata, to : Metadata)
  {% end %}

  fun set_current_debug_location = LLVMSetCurrentDebugLocation2(LibLLVM::BuilderRef, LibC::Int, LibC::Int, Metadata, Metadata)

  fun build_cmpxchg = LLVMExtBuildCmpxchg(builder : LibLLVM::BuilderRef, pointer : LibLLVM::ValueRef, cmp : LibLLVM::ValueRef, new : LibLLVM::ValueRef, success_ordering : LLVM::AtomicOrdering, failure_ordering : LLVM::AtomicOrdering) : LibLLVM::ValueRef
  fun set_ordering = LLVMExtSetOrdering(value : LibLLVM::ValueRef, ordering : LLVM::AtomicOrdering)
end
