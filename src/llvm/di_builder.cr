struct LLVM::DIBuilder
  def initialize(llvm_module)
    @unwrap = LibLLVMExt.create_di_builder(llvm_module)
  end

  def create_compile_unit(lang, file, dir, producer, optimized, flags, runtime_version)
    LibLLVMExt.di_builder_create_compile_unit(self, lang, file, dir, producer, optimized ? 1 : 0, flags, runtime_version)
  end

  def create_basic_type(name, size_in_bits, align_in_bits, encoding)
    LibLLVMExt.di_builder_create_basic_type(self, name, size_in_bits, align_in_bits, encoding.value)
  end

  def get_or_create_type_array(types : Array(LibLLVMExt::Metadata))
    LibLLVMExt.di_builder_get_or_create_type_array(self, types.buffer, types.size)
  end

  def create_subroutine_type(file, parameter_types)
    LibLLVMExt.di_builder_create_subroutine_type(self, file, parameter_types)
  end

  def create_file(file, dir)
    LibLLVMExt.di_builder_create_file(self, file, dir)
  end

  def create_lexical_block(scope, file, line, column)
    LibLLVMExt.di_builder_create_lexical_block(self, scope, file, line, column)
  end

  def create_function(scope, name, linkage_name, file, line, composite_type, is_local_to_unit, is_definition,
                      scope_line, flags, is_optimized, func)
    LibLLVMExt.di_builder_create_function(self, scope, name, linkage_name, file, line, composite_type, is_local_to_unit, is_definition,
                                          scope_line, flags, is_optimized, func)
  end

  def create_local_variable(tag, scope, name, file, line, type)
    LibLLVMExt.di_builder_create_local_variable(self, tag.value, scope, name, file, line, type, 0, 0, 0)
  end

  def create_expression(addr, length)
    LibLLVMExt.di_builder_create_expression(self, addr, length)
  end

  def insert_declare_at_end(storage, var_info, expr, block)
    LibLLVMExt.di_builder_insert_declare_at_end(self, storage, var_info, expr, block)
  end

  def get_or_create_array(elements : Array(LibLLVMExt::Metadata))
    LibLLVMExt.di_builder_get_or_create_array(self, elements.buffer, elements.size)
  end

  def create_enumerator(name, value)
    LibLLVMExt.di_builder_create_enumerator(self, name, value)
  end

  def create_enumeration_type(scope, name, file, line_number, size_in_bits, align_in_bits, elements, underlying_type)
    LibLLVMExt.di_builder_create_enumeration_type(self, scope, name, file, line_number, size_in_bits,
      align_in_bits, elements, underlying_type)
  end

  def create_struct_type(scope, name, file, line, size_in_bits, align_in_bits, flags, derived_from, element_types)
    LibLLVMExt.di_builder_create_struct_type(self, scope, name, file, line, size_in_bits, align_in_bits,
      flags, derived_from, element_types)
  end

  def create_member_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, ty)
    LibLLVMExt.di_builder_create_member_type(self, scope, name, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, ty)
  end

  def create_pointer_type(pointee, size_in_bits, align_in_bits, name)
    LibLLVMExt.di_builder_create_pointer_type(self, pointee, size_in_bits, align_in_bits, name)
  end

  def temporary_md_node(context)
    LibLLVMExt.temporary_md_node(context, nil, 0) as LibLLVMExt::Metadata
  end

  def replace_all_uses(from, to)
    LibLLVMExt.metadata_replace_all_uses_with(from, to)
  end

  def finalize
    LibLLVMExt.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end
end
