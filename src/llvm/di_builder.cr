struct LLVM::DIBuilder
  def initialize(llvm_module)
    @unwrap = LibLLVMExt.create_di_builder(llvm_module)
  end

  def create_compile_unit(lang, file, dir, producer, optimized, flags, runtime_version)
    LibLLVMExt.di_builder_create_compile_unit(self, lang, file, dir, producer, optimized ? 1 : 0, flags, runtime_version)
  end

  def create_basic_type(name, size_in_bits, align_in_bits, encoding)
    LibLLVMExt.di_builder_create_basic_type(self, name, size_in_bits.to_u64, align_in_bits.to_u64,
      LibC::UInt.new(encoding.value))
  end

  def get_or_create_type_array(types : Array(LibLLVMExt::Metadata))
    LibLLVMExt.di_builder_get_or_create_type_array(self, types.buffer, LibC::SizeT.new(types.size))
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
    LibLLVMExt.di_builder_create_function(self, scope, name, linkage_name, file, LibC::UInt.new(line), composite_type, is_local_to_unit, is_definition,
                                          LibC::UInt.new(scope_line), flags, is_optimized, func)
  end

  def create_local_variable(tag, scope, name, file, line, type)
    LibLLVMExt.di_builder_create_local_variable(self, LibC::UInt.new(tag.value), scope, name,
      file, LibC::UInt.new(line), type, 0, 0_u32, 0_u32)
  end

  def create_expression(addr, length)
    LibLLVMExt.di_builder_create_expression(self, addr, LibC::SizeT.new(length))
  end

  def insert_declare_at_end(storage, var_info, expr, block)
    LibLLVMExt.di_builder_insert_declare_at_end(self, storage, var_info, expr, block)
  end

  def finalize
    LibLLVMExt.di_builder_finalize(self)
  end

  def to_unsafe
    @unwrap
  end
end
