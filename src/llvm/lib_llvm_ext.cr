@[Link(ldflags: "#{__DIR__}/ext/llvm_ext.o")]
lib LibLLVMExt
  type DIBuilder = Void*
  type Metadata = Void*

  fun create_di_builder = LLVMNewDIBuilder(LibLLVM::ModuleRef) : DIBuilder
  fun di_builder_finalize = LLVMDIBuilderFinalize(DIBuilder)
  fun di_builder_create_function = LLVMDIBuilderCreateFunction(
    builder : DIBuilder, scope : Metadata, name : LibC::Char*,
    linkage_name : LibC::Char*, file : Metadata, line : LibC::UInt,
    composite_type : Metadata, is_local_to_unit : LibC::Int, is_definition : LibC::Int,
    scope_line : LibC::UInt, flags : LibC::UInt, is_optimized : LibC::Int, func : LibLLVM::ValueRef) : Metadata
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

  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilder, data : Metadata*, length : LibC::SizeT) : Metadata
  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(builder : DIBuilder, file : Metadata, parameter_types : Metadata) : Metadata
  fun set_current_debug_location = LLVMSetCurrentDebugLocation2(LibLLVM::BuilderRef, LibC::Int, LibC::Int, Metadata, Metadata)
end
