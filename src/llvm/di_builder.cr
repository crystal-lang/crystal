require "./lib_llvm"

struct LLVM::DIBuilder
  def initialize(@llvm_module : Module)
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

  def create_lexical_block(scope, file_scope, line, column)
    LibLLVMExt.di_builder_create_lexical_block(self, scope, file_scope, line, column)
  end

  def create_lexical_block_file(scope, file_scope, discriminator = 0)
    LibLLVM.di_builder_create_lexical_block_file(self, scope, file_scope, discriminator)
  end

  def create_function(scope, name, linkage_name, file, line, composite_type, is_local_to_unit, is_definition,
                      scope_line, flags, is_optimized, func)
    LibLLVMExt.di_builder_create_function(self, scope, name, linkage_name, file, line, composite_type,
      is_local_to_unit, is_definition, scope_line, flags, is_optimized, func)
  end

  def create_auto_variable(scope, name, file, line, type, align_in_bits)
    LibLLVMExt.di_builder_create_auto_variable(self, scope, name, file, line, type, 1, DIFlags::Zero, align_in_bits)
  end

  def create_parameter_variable(scope, name, argno, file, line, type)
    LibLLVMExt.di_builder_create_parameter_variable(self, scope, name, argno, file, line, type, 1, DIFlags::Zero)
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

  def create_union_type(scope, name, file, line, size_in_bits, align_in_bits, flags, element_types)
    LibLLVMExt.di_builder_create_union_type(self, scope, name, file, line, size_in_bits, align_in_bits,
      flags, element_types)
  end

  def create_array_type(size_in_bits, align_in_bits, type, subs)
    elements = self.get_or_create_array(subs)
    LibLLVMExt.di_builder_create_array_type(self, size_in_bits, align_in_bits, type, elements)
  end

  def create_member_type(scope, name, file, line, size_in_bits, align_in_bits, offset_in_bits, flags, ty)
    LibLLVMExt.di_builder_create_member_type(self, scope, name, file, line, size_in_bits, align_in_bits,
      offset_in_bits, flags, ty)
  end

  def create_pointer_type(pointee, size_in_bits, align_in_bits, name)
    LibLLVMExt.di_builder_create_pointer_type(self, pointee, size_in_bits, align_in_bits, name)
  end

  def create_replaceable_composite_type(scope, name, file, line, context : Context)
    LibLLVMExt.di_builder_create_replaceable_composite_type(self, scope, name, file, line)
  end

  def replace_temporary(from, to)
    LibLLVMExt.di_builder_replace_temporary(self, from, to)
  end

  def create_unspecified_type(name : String)
    LibLLVM.di_builder_create_unspecified_yype(self, name, name.size)
  end

  def location_get_line(location : LibLLVMExt::Metadata)
    LibLLVM.location_get_line(location)
  end

  def location_get_column(location : LibLLVMExt::Metadata)
    LibLLVM.location_get_column(location)
  end

  def location_get_scope(location : LibLLVMExt::Metadata)
    LibLLVM.location_get_scope(location)
  end

  def scope_get_file(scope : LibLLVMExt::Metadata)
    LibLLVM.scope_get_file(scope)
  end

  def file_get_directory(file : LibLLVMExt::Metadata)
    ptr = LibLLVM.file_get_directory(file, out dir_name_size)
    str = String.new(ptr, dir_name_size)
  end

  def file_get_filename(file : LibLLVMExt::Metadata)
    ptr = LibLLVM.file_get_filename(file, out file_name_size)
    str = String.new(ptr, file_name_size)
  end

  def variable_get_file(variable : LibLLVMExt::Metadata)
    LibLLVM.variable_get_file(variable)
  end

  def variable_get_scope(variable : LibLLVMExt::Metadata)
    LibLLVM.variable_get_scope(variable)
  end

  def variable_get_line(variable : LibLLVMExt::Metadata)
    LibLLVM.variable_get_line(variable)
  end

  def get_or_create_array_subrange(lo, count)
    LibLLVMExt.di_builder_get_or_create_array_subrange(self, lo, count)
  end

  def end
    LibLLVMExt.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end
end
