class Crystal::CodeGenVisitor < Crystal::Visitor
  def assign(target_pointer, target_type, value_type, value)
    if target_type == value_type
      store to_rhs(value, target_type), target_pointer
    else
      assign_distinct target_pointer, target_type, value_type, value
    end
  end

  def assign_distinct(target_pointer, target_type : Type, value_type : NonGenericModuleType, value)
    assign target_pointer, target_type, value_type.including_types.not_nil!, value
  end

  def assign_distinct(target_pointer, target_type : NonGenericModuleType, value_type : Type, value)
    assign target_pointer, target_type.including_types.not_nil!, value_type, value
  end

  def assign_distinct(target_pointer, target_type : NilableType, value_type : Type, value)
    store upcast(value, target_type, value_type), target_pointer
  end

  def assign_distinct(target_pointer, target_type : ReferenceUnionType, value_type : ReferenceUnionType, value)
    store value, target_pointer
  end

  def assign_distinct(target_pointer, target_type : ReferenceUnionType, value_type : VirtualType, value)
    store value, target_pointer
  end

  def assign_distinct(target_pointer, target_type : ReferenceUnionType, value_type : Type, value)
    store cast_to(value, target_type), target_pointer
  end

  def assign_distinct(target_pointer, target_type : NilableReferenceUnionType, value_type : Type, value)
    store upcast(value, target_type, value_type), target_pointer
  end

  def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : MixedUnionType, value)
    casted_value = cast_to_pointer value, target_type
    store load(casted_value), target_pointer
  end

  def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : NilableType, value)
    store_in_union target_pointer, value_type, value
  end

  def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : VoidType, value)
    store type_id(value_type), union_type_id(target_pointer)
  end

  def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : BoolType, value)
    store_bool_in_union target_pointer, value
  end

  def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : NilType, value)
    store_nil_in_union target_pointer, target_type
  end

  def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : Type, value)
    store_in_union target_pointer, value_type, to_rhs(value, value_type)
  end

  def assign_distinct(target_pointer, target_type : VirtualType, value_type : MixedUnionType, value)
    casted_value = cast_to_pointer(union_value(value), target_type)
    store load(casted_value), target_pointer
  end

  def assign_distinct(target_pointer, target_type : VirtualType, value_type : Type, value)
    store cast_to(value, target_type), target_pointer
  end

  def assign_distinct(target_pointer, target_type : VirtualMetaclassType, value_type : MetaclassType, value)
    store value, target_pointer
  end

  def assign_distinct(target_pointer, target_type : NilableFunType, value_type : NilType, value)
    nilable_fun = make_nilable_fun target_type
    store nilable_fun, target_pointer
  end

  def assign_distinct(target_pointer, target_type : NilableFunType, value_type : FunInstanceType, value)
    store value, target_pointer
  end

  def assign_distinct(target_pointer, target_type : NilableFunType, value_type : TypeDefType, value)
    assign_distinct target_pointer, target_type, value_type.typedef, value
  end

  def assign_distinct(target_pointer, target_type : NilablePointerType, value_type : NilType, value)
    store llvm_type(target_type).null, target_pointer
  end

  def assign_distinct(target_pointer, target_type : NilablePointerType, value_type : PointerInstanceType, value)
    store value, target_pointer
  end

  def assign_distinct(target_pointer, target_type : NilablePointerType, value_type : TypeDefType, value)
    assign_distinct target_pointer, target_type, value_type.typedef, value
  end

  def assign_distinct(target_pointer, target_type : Type, value_type : Type, value)
    raise "Bug: trying to assign #{target_type} <- #{value_type}"
  end

  def downcast(value, to_type, from_type : VoidType, already_loaded)
    value
  end

  def downcast(value, to_type, from_type : NonGenericModuleType, already_loaded)
    if from_type == to_type
      value = to_lhs(value, from_type) unless already_loaded
    else
      value = downcast(value, to_type, from_type.including_types.not_nil!, already_loaded)
    end
    value
  end

  def downcast(value, to_type, from_type : Type, already_loaded)
    unless already_loaded
      value = to_lhs(value, from_type)
    end
    if from_type != to_type
      value = downcast_distinct value, to_type, from_type
    end
    value
  end

  def downcast_distinct(value, to_type : NilType, from_type : Type)
    llvm_nil
  end

  def downcast_distinct(value, to_type, from_type : MetaclassType | GenericClassInstanceMetaclassType | VirtualMetaclassType)
    value
  end

  def downcast_distinct(value, to_type : VirtualType, from_type : VirtualType)
    value
  end

  def downcast_distinct(value, to_type : MixedUnionType, from_type : VirtualType)
    # This happens if the restriction is a union:
    # we keep each of the union types as the result, we don't fully merge
    union_ptr = alloca llvm_type(to_type)
    store_in_union union_ptr, from_type, value
    union_ptr
  end

  def downcast_distinct(value, to_type : ReferenceUnionType, from_type : VirtualType)
    # This happens if the restriction is a union:
    # we keep each of the union types as the result, we don't fully merge
    value
  end

  def downcast_distinct(value, to_type : NonGenericClassType | GenericClassInstanceType, from_type : VirtualType)
    cast_to value, to_type
  end

  def downcast_distinct(value, to_type : Type, from_type : NilableType)
    value
  end

  def downcast_distinct(value, to_type : FunInstanceType, from_type : NilableFunType)
    value
  end

  def downcast_distinct(value, to_type : TypeDefType, from_type : NilableFunType)
    downcast_distinct value, to_type.typedef, from_type
  end

  def downcast_distinct(value, to_type : PointerInstanceType, from_type : NilablePointerType)
    value
  end

  def downcast_distinct(value, to_type : TypeDefType, from_type : NilablePointerType)
    downcast_distinct value, to_type.typedef, from_type
  end

  def downcast_distinct(value, to_type : ReferenceUnionType, from_type : ReferenceUnionType)
    value
  end

  def downcast_distinct(value, to_type : VirtualType, from_type : ReferenceUnionType)
    value
  end

  def downcast_distinct(value, to_type : Type, from_type : ReferenceUnionType)
    cast_to value, to_type
  end

  def downcast_distinct(value, to_type : VirtualType, from_type : NilableReferenceUnionType)
    value
  end

  def downcast_distinct(value, to_type : ReferenceUnionType, from_type : NilableReferenceUnionType)
    value
  end

  def downcast_distinct(value, to_type : NilableType, from_type : NilableReferenceUnionType)
    cast_to value, to_type
  end

  def downcast_distinct(value, to_type : Type, from_type : NilableReferenceUnionType)
    cast_to value, to_type
  end

  def downcast_distinct(value, to_type : MixedUnionType, from_type : MixedUnionType)
    cast_to_pointer value, to_type
  end

  def downcast_distinct(value, to_type : NilableType, from_type : MixedUnionType)
    load cast_to_pointer(union_value(value), to_type)
  end

  def downcast_distinct(value, to_type : BoolType, from_type : MixedUnionType)
    value_ptr = union_value(value)
    value = cast_to_pointer(value_ptr, @mod.int8)
    value = load(value)
    trunc value, LLVM::Int1
  end

  def downcast_distinct(value, to_type : Type, from_type : MixedUnionType)
    value_ptr = union_value(value)
    value = cast_to_pointer(value_ptr, to_type)
    to_lhs value, to_type
  end

  def downcast_distinct(value, to_type : FunInstanceType, from_type : FunInstanceType)
    # Nothing to do
    value
  end

  def downcast_distinct(value, to_type : NonGenericModuleType, from_type : Type)
    value
  end

  def downcast_distinct(value, to_type : Type, from_type : Type)
    raise "Bug: trying to downcast #{to_type} <- #{from_type}"
  end

  def upcast(value, to_type, from_type)
    if to_type != from_type
      value = upcast_distinct(value, to_type, from_type)
    end
    value
  end

  def upcast_distinct(value, to_type : MetaclassType | GenericClassInstanceMetaclassType | VirtualMetaclassType, from_type)
    value
  end

  def upcast_distinct(value, to_type : VirtualType, from_type)
    cast_to value, to_type
  end

  def upcast_distinct(value, to_type : NilableType, from_type : NilType?)
    llvm_type(to_type).null
  end

  def upcast_distinct(value, to_type : NilableType, from_type : Type)
    value
  end

  def upcast_distinct(value, to_type : NilableReferenceUnionType, from_type : NilType?)
    llvm_type(to_type).null
  end

  def upcast_distinct(value, to_type : NilableReferenceUnionType, from_type : Type)
    cast_to value, to_type
  end

  def upcast_distinct(value, to_type : NilableFunType, from_type : NilType)
    make_nilable_fun to_type
  end

  def upcast_distinct(value, to_type : NilableFunType, from_type : FunInstanceType)
    value
  end

  def upcast_distinct(value, to_type : NilableFunType, from_type : TypeDefType)
    upcast_distinct value, to_type, from_type.typedef
  end

  def upcast_distinct(value, to_type : NilablePointerType, from_type : NilType)
    llvm_type(to_type).null
  end

  def upcast_distinct(value, to_type : NilablePointerType, from_type : PointerInstanceType)
    value
  end

  def upcast_distinct(value, to_type : NilablePointerType, from_type : TypeDefType)
    upcast_distinct value, to_type, from_type.typedef
  end

  def upcast_distinct(value, to_type : ReferenceUnionType, from_type)
    cast_to value, to_type
  end

  def upcast_distinct(value, to_type : MixedUnionType, from_type : MixedUnionType)
    cast_to_pointer value, to_type
  end

  def upcast_distinct(value, to_type : MixedUnionType, from_type : VoidType)
    union_ptr = alloca(llvm_type(to_type))
    store type_id(from_type), union_type_id(union_ptr)
    union_ptr
  end

  def upcast_distinct(value, to_type : MixedUnionType, from_type : BoolType)
    union_ptr = alloca(llvm_type(to_type))
    store_bool_in_union union_ptr, value
    union_ptr
  end

  def upcast_distinct(value, to_type : MixedUnionType, from_type : NilType)
    union_ptr = alloca(llvm_type(to_type))
    store_nil_in_union union_ptr, to_type
    union_ptr
  end

  def upcast_distinct(value, to_type : MixedUnionType, from_type : Type)
    union_ptr = alloca(llvm_type(to_type))
    store_in_union(union_ptr, from_type, to_rhs(value, from_type))
    union_ptr
  end

  def upcast_distinct(value, to_type : CEnumType, from_type : Type)
    value
  end

  def upcast_distinct(value, to_type : NonGenericModuleType, from_type : Type)
    upcast_distinct value, to_type.including_types.not_nil!, from_type
  end

  def upcast_distinct(value, to_type : Type, from_type : Type)
    raise "Bug: trying to upcast #{to_type} <- #{from_type}"
  end

  def store_in_union(union_pointer, value_type, value)
    store type_id(value, value_type), union_type_id(union_pointer)
    casted_value_ptr = cast_to_pointer(union_value(union_pointer), value_type)
    store value, casted_value_ptr
  end

  def store_bool_in_union(union_pointer, value)
    store type_id(value, @mod.bool), union_type_id(union_pointer)
    bool_as_i64 = builder.zext(value, llvm_type(@mod.int64))
    casted_value_ptr = cast_to_pointer(union_value(union_pointer), @mod.int64)
    store bool_as_i64, casted_value_ptr
  end

  def store_nil_in_union(union_pointer, target_type)
    union_value_type = llvm_union_value_type(target_type)
    value = union_value_type.null

    store type_id(value, @mod.nil), union_type_id(union_pointer)
    casted_value_ptr = bit_cast union_value(union_pointer), union_value_type.pointer
    store value, casted_value_ptr
  end
end
