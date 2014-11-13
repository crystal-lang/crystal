class Crystal::CodeGenVisitor < Crystal::Visitor
  def type_id(value, type : NilableType)
    builder.select null_pointer?(value), type_id(@mod.nil), type_id(type.not_nil_type)
  end

  def type_id(value, type : ReferenceUnionType | VirtualType)
    load(value)
  end

  def type_id(value, type : NilableReferenceUnionType)
    nil_block, not_nil_block, exit_block = new_blocks "nil", "not_nil", "exit"
    phi_table = LLVM::PhiTable.new

    cond null_pointer?(value), nil_block, not_nil_block

    position_at_end nil_block
    phi_table.add insert_block, type_id(@mod.nil)
    br exit_block

    position_at_end not_nil_block
    phi_table.add insert_block, load(value)
    br exit_block

    position_at_end exit_block
    phi LLVM::Int32, phi_table
  end

  def type_id(value, type : NilablePointerType)
    builder.select null_pointer?(value), type_id(@mod.nil), type_id(type.pointer_type)
  end

  def type_id(value, type : NilableFunType)
    fun_ptr = extract_value value, 0
    builder.select null_pointer?(fun_ptr), type_id(@mod.nil), type_id(type.fun_type)
  end

  def type_id(value, type : MixedUnionType)
    load(union_type_id(value))
  end

  def type_id(value, type : VirtualMetaclassType)
    value
  end

  def type_id(value, type : Program)
    type_id(type)
  end

  def type_id(value, type : NonGenericModuleType)
    type_id(value, type.including_types.not_nil!)
  end

  def type_id(value, type : GenericClassType)
    type_id(value, type.including_types.not_nil!)
  end

  def type_id(value, type)
    type_id(type)
  end

  def type_id(type)
    int(@llvm_id.type_id(type))
  end
end
