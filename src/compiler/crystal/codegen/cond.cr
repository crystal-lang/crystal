require "./codegen"

class Crystal::CodeGenVisitor
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
    union_types = type.expand_union_types

    has_nil = union_types.any? &.nil_type?
    has_bool = union_types.any? &.bool_type?
    has_pointer = union_types.any? &.is_a?(PointerInstanceType)

    cond = llvm_true

    if has_nil || has_bool || has_pointer
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

      if has_pointer
        union_types.each do |union_type|
          next unless union_type.is_a?(PointerInstanceType)

          is_pointer = equal? type_id, type_id(union_type)
          pointer_value = load(bit_cast union_value(@last), llvm_type(union_type).pointer)
          pointer_null = null_pointer?(pointer_value)
          cond = and cond, not(and(is_pointer, pointer_null))
        end
      end
    end

    cond
  end

  def codegen_cond(type : Type)
    llvm_true
  end
end
