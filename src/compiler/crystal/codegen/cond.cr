class Crystal::CodeGenVisitor < Crystal::Visitor
  def codegen_cond(type : NilType)
    llvm_false
  end

  def codegen_cond(type : BoolType)
    @last
  end

  def codegen_cond(type : TypeDefType)
    codegen_cond type.typedef
  end

  def codegen_cond(type : NilableType | NilableReferenceUnionType | PointerInstanceType | NilablePointerType)
    not_null_pointer? @last
  end

  def codegen_cond(type : NilableFunType)
    fun_ptr = extract_value @last, 0
    not_null_pointer? fun_ptr
  end

  def codegen_cond(type : MixedUnionType)
    has_nil = type.union_types.any? &.nil_type?
    has_bool = type.union_types.any? &.bool_type?

    cond = llvm_true

    if has_nil || has_bool
      type_id = load union_type_id(@last)

      if has_nil
        is_nil = equal? type_id, type_id(@mod.nil)
        cond = and cond, not(is_nil)
      end

      if has_bool
        value = load(bit_cast union_value(@last), LLVM::Int1.pointer)
        is_bool = equal? type_id, type_id(@mod.bool)
        cond = and cond, not(and(is_bool, not(value)))
      end
    end

    cond
  end

  def codegen_cond(type : Type)
    llvm_true
  end
end
