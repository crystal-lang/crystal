require "./lib_llvm"

struct LLVM::DIBuilder
  private DW_TAG_structure_type = 19

  private def initialize(@unwrap : LibLLVM::DIBuilderRef, @llvm_module : Module)
  end

  def self.new(mod : LLVM::Module)
    new(LibLLVM.create_di_builder(mod), mod)
  end

  def dispose
    LibLLVM.dispose_di_builder(self)
  end

  def create_compile_unit(lang : DwarfSourceLanguage, file, dir, producer, optimized, flags, runtime_version)
    file = create_file(file, dir)
    {% if LibLLVM::IS_LT_110 %}
      LibLLVM.di_builder_create_compile_unit(self,
        lang, file, producer, producer.bytesize, optimized ? 1 : 0, flags, flags.bytesize, runtime_version,
        split_name: nil, split_name_len: 0, kind: LibLLVM::DWARFEmissionKind::Full, dwo_id: 0,
        split_debug_inlining: 1, debug_info_for_profiling: 0,
      )
    {% else %}
      LibLLVM.di_builder_create_compile_unit(self,
        lang, file, producer, producer.bytesize, optimized ? 1 : 0, flags, flags.bytesize, runtime_version,
        split_name: nil, split_name_len: 0, kind: LibLLVM::DWARFEmissionKind::Full, dwo_id: 0,
        split_debug_inlining: 1, debug_info_for_profiling: 0, sys_root: nil, sys_root_len: 0, sdk: nil, sdk_len: 0,
      )
    {% end %}
  end

  @[Deprecated("Pass an `LLVM::DwarfSourceLanguage` for `lang` instead")]
  def create_compile_unit(lang cpp_lang_code, file, dir, producer, optimized, flags, runtime_version)
    # map the c++ values from `llvm::dwarf::SourceLanguage` to the c values from `LLVMDWARFSourceLanguage`
    c_lang_code =
      case cpp_lang_code
      when 0x8001; DwarfSourceLanguage::Mips_Assembler
      when 0x8e57; DwarfSourceLanguage::GOOGLE_RenderScript
      when 0xb000; DwarfSourceLanguage::BORLAND_Delphi
      else         DwarfSourceLanguage.new(lang - 1)
      end

    create_compile_unit(c_lang_code, file, dir, producer, optimized, flags, runtime_version)
  end

  def create_basic_type(name, size_in_bits, align_in_bits, encoding)
    LibLLVM.di_builder_create_basic_type(self, name, name.bytesize, size_in_bits, encoding.value, DIFlags::Zero)
  end

  def get_or_create_type_array(types : Array(LibLLVM::MetadataRef))
    LibLLVM.di_builder_get_or_create_type_array(self, types, types.size)
  end

  def create_subroutine_type(file, parameter_types)
    LibLLVM.di_builder_create_subroutine_type(self, file, parameter_types, parameter_types.size, DIFlags::Zero)
  end

  def create_file(file, dir)
    LibLLVM.di_builder_create_file(self, file, file.bytesize, dir, dir.bytesize)
  end

  def create_lexical_block(scope, file_scope, line, column)
    LibLLVM.di_builder_create_lexical_block(self, scope, file_scope, line, column)
  end

  def create_lexical_block_file(scope, file_scope, discriminator = 0)
    LibLLVM.di_builder_create_lexical_block_file(self, scope, file_scope, discriminator)
  end

  def create_function(scope, name, linkage_name, file, line, composite_type, is_local_to_unit, is_definition,
                      scope_line, flags, is_optimized, func)
    sub = LibLLVM.di_builder_create_function(self, scope, name, name.bytesize,
      linkage_name, linkage_name.bytesize, file, line, composite_type, is_local_to_unit ? 1 : 0,
      is_definition ? 1 : 0, scope_line, flags, is_optimized ? 1 : 0)
    LibLLVM.set_subprogram(func, sub)
    sub
  end

  def create_auto_variable(scope, name, file, line, type, align_in_bits, flags = DIFlags::Zero)
    LibLLVM.di_builder_create_auto_variable(self, scope, name, name.bytesize, file, line, type, 1, flags, align_in_bits)
  end

  def create_parameter_variable(scope, name, argno, file, line, type, flags = DIFlags::Zero)
    LibLLVM.di_builder_create_parameter_variable(self, scope, name, name.bytesize, argno, file, line, type, 1, flags)
  end

  def create_expression(addr, length)
    LibLLVM.di_builder_create_expression(self, addr, length)
  end

  def insert_declare_at_end(storage, var_info, expr, dl : LibLLVM::MetadataRef, block)
    LibLLVM.di_builder_insert_declare_at_end(self, storage, var_info, expr, dl, block)
  end

  def get_or_create_array(elements : Array(LibLLVM::MetadataRef))
    LibLLVM.di_builder_get_or_create_array(self, elements, elements.size)
  end

  def create_enumerator(name, value)
    {% if LibLLVM::IS_LT_90 %}
      LibLLVMExt.di_builder_create_enumerator(self, name, value)
    {% else %}
      LibLLVM.di_builder_create_enumerator(self, name, name.bytesize, value, 0)
    {% end %}
  end

  def create_enumeration_type(scope, name, file, line_number, size_in_bits, align_in_bits, elements, underlying_type)
    LibLLVM.di_builder_create_enumeration_type(self, scope, name, name.bytesize, file, line_number,
      size_in_bits, align_in_bits, elements, elements.size, underlying_type)
  end

  def create_struct_type(scope, name, file, line, size_in_bits, align_in_bits, flags, derived_from, element_types)
    LibLLVM.di_builder_create_struct_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, align_in_bits, flags, derived_from, element_types, element_types.size, 0, nil, nil, 0)
  end

  def create_union_type(scope, name, file, line, size_in_bits, align_in_bits, flags, element_types)
    LibLLVM.di_builder_create_union_type(self, scope, name, name.bytesize, file, line,
      size_in_bits, align_in_bits, flags, element_types, element_types.size, 0, nil, 0)
  end

  def create_array_type(size_in_bits, align_in_bits, type, subs)
    LibLLVM.di_builder_create_array_type(self, size_in_bits, align_in_bits, type, subs, subs.size)
  end

  def create_member_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, ty)
    LibLLVM.di_builder_create_member_type(self, scope, name, name.bytesize, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, ty)
  end

  def create_pointer_type(pointee, size_in_bits, align_in_bits, name)
    LibLLVM.di_builder_create_pointer_type(self, pointee, size_in_bits, align_in_bits, 0, name, name.bytesize)
  end

  def create_replaceable_composite_type(scope, name, file, line)
    LibLLVM.di_builder_create_replaceable_composite_type(self, DW_TAG_structure_type, name, name.bytesize,
      scope, file, line, 0, 0, 0, DIFlags::FwdDecl, nil, 0)
  end

  def replace_temporary(from, to)
    LibLLVM.metadata_replace_all_uses_with(from, to)
  end

  def create_unspecified_type(name : String)
    LibLLVM.di_builder_create_unspecified_type(self, name, name.bytesize)
  end

  def get_or_create_array_subrange(lo, count)
    LibLLVM.di_builder_get_or_create_subrange(self, lo, count)
  end

  def end
    LibLLVM.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end

  @[Deprecated("Use a `LibLLVM::MetadataRef` for `dl` instead")]
  def insert_declare_at_end(storage, var_info, expr, dl : LibLLVM::ValueRef | LLVM::Value, block)
    dl = dl.to_unsafe unless dl.is_a?(LibLLVM::ValueRef)
    insert_declare_at_end(storage, var_info, expr, LibLLVM.value_as_metadata(dl), block)
  end

  @[Deprecated("Pass an array for `parameter_types` directly")]
  def create_subroutine_type(file, parameter_types : LibLLVM::MetadataRef)
    create_subroutine_type(file, extract_metadata_array(parameter_types))
  end

  @[Deprecated("Pass an array for `elements` directly")]
  def create_enumeration_type(scope, name, file, line_number, size_in_bits, align_in_bits, elements : LibLLVM::MetadataRef, underlying_type)
    create_enumeration_type(scope, name, file, line_number, size_in_bits, align_in_bits, extract_metadata_array(elements), underlying_type)
  end

  @[Deprecated("Pass an array for `element_types` directly")]
  def create_struct_type(scope, name, file, line, size_in_bits, align_in_bits, flags, derived_from, element_types : LibLLVM::MetadataRef)
    create_struct_type(scope, name, file, line, size_in_bits, align_in_bits, flags, derived_from, extract_metadata_array(element_types))
  end

  @[Deprecated("Pass an array for `element_types` directly")]
  def create_union_type(scope, name, file, line, size_in_bits, align_in_bits, flags, element_types : LibLLVM::MetadataRef)
    create_union_type(scope, name, file, line, size_in_bits, align_in_bits, flags, extract_metadata_array(element_types))
  end

  @[Deprecated("Pass an array for `subs` directly")]
  def create_array_type(size_in_bits, align_in_bits, type, subs : LibLLVM::MetadataRef)
    create_array_type(size_in_bits, align_in_bits, type, extract_metadata_array(subs))
  end

  private def extract_metadata_array(metadata : LibLLVM::MetadataRef)
    metadata_as_value = LibLLVM.metadata_as_value(@llvm_module.context, metadata)
    operand_count = LibLLVM.get_md_node_num_operands(metadata_as_value).to_i
    operands = Pointer(LibLLVM::ValueRef).malloc(operand_count)
    LibLLVM.get_md_node_operands(metadata_as_value, operands)
    Slice.new(operand_count) { |i| LibLLVM.value_as_metadata(operands[i]) }
  end
end
