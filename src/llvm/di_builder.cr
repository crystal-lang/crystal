require "./lib_llvm"

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
    LibLLVMExt.di_builder_get_or_create_type_array(self, types, types.size)
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
    {% if LibLLVM::IS_36 || LibLLVM::IS_35 %}
      LibLLVMExt.di_builder_create_function(self, scope, name, linkage_name, file, line, composite_type,
                                            is_local_to_unit ? 1 : 0,
                                            is_definition ? 1 : 0,
                                            scope_line, flags,
                                            is_optimized ? 1 : 0, func)
    {% else %}
      LibLLVMExt.di_builder_create_function(self, scope, name, linkage_name, file, line, composite_type,
                                            is_local_to_unit, is_definition, scope_line, flags, is_optimized, func)
    {% end %}
  end

  def create_auto_variable(scope, name, file, line, type)
    LibLLVMExt.di_builder_create_auto_variable(self, scope, name, file, line, type, 0, 0)
  end

  def create_parameter_variable(scope, name, argno, file, line, type)
    LibLLVMExt.di_builder_create_parameter_variable(self, scope, name, argno, file, line, type, 0, 0)
  end

  def create_expression(addr, length)
    LibLLVMExt.di_builder_create_expression(self, addr, length)
  end

  def insert_declare_at_end(storage, var_info, expr, dl, block)
    LibLLVMExt.di_builder_insert_declare_at_end(self, storage, var_info, expr, dl, block)
  end

  def get_or_create_array(elements : Array(LibLLVMExt::Metadata))
    LibLLVMExt.di_builder_get_or_create_array(self, elements, elements.size)
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

  def create_replaceable_composite_type(scope, name, file, line)
    {% if LibLLVM::IS_35 || LibLLVM::IS_36 %}
      LibLLVMExt.temporary_md_node(LLVM::Context.global, nil, 0).as(LibLLVMExt::Metadata)
    {% else %}
      LibLLVMExt.di_builder_create_replaceable_composite_type(self, scope, name, file, line)
    {% end %}
  end

  def replace_temporary(from, to)
    {% if LibLLVM::IS_35 || LibLLVM::IS_36 %}
      LibLLVMExt.metadata_replace_all_uses_with(from, to)
    {% else %}
      LibLLVMExt.di_builder_replace_temporary(self, from, to)
    {% end %}
  end

  def finalize
    LibLLVMExt.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end
end
