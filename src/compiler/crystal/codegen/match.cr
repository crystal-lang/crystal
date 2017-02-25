require "./codegen"

class Crystal::CodeGenVisitor
  def match_type_id(type, restriction, type_id)
    match_type_id_impl(type.remove_indirection, restriction.remove_indirection, type_id)
  end

  private def match_type_id_impl(type, restriction : Program, type_id)
    llvm_true
  end

  private def match_type_id_impl(type, restriction : FileModule, type_id)
    llvm_true
  end

  private def match_type_id_impl(type : UnionType | VirtualType | VirtualMetaclassType, restriction, type_id)
    match_any_type_id(restriction, type_id)
  end

  private def match_type_id_impl(type : AliasType, restriction, type_id)
    match_type_id type.aliased_type, restriction, type_id
  end

  private def match_type_id_impl(type, restriction, type_id)
    equal? type_id(restriction), type_id
  end

  def match_any_type_id(type, type_id)
    match_any_type_id_impl(type.remove_indirection, type_id)
  end

  private def match_any_type_id_impl(type : UnionType | VirtualType | VirtualMetaclassType, type_id)
    match_any_type_id_with_function(type, type_id)
  end

  private def match_any_type_id_impl(type, type_id)
    equal? type_id(type), type_id
  end

  private def match_any_type_id_with_function(type, type_id)
    match_fun_name = "~match<#{type}>"
    func = @main_mod.functions[match_fun_name]? || create_match_fun(match_fun_name, type)
    func = check_main_fun match_fun_name, func
    return call func, [type_id] of LLVM::Value
  end

  private def create_match_fun(name, type)
    in_main do
      define_main_function(name, ([llvm_context.int32]), llvm_context.int1) do |func|
        type_id = func.params.first
        create_match_fun_body(type, type_id)
      end
    end
  end

  private def create_match_fun_body(type : UnionType, type_id)
    result = nil
    type.expand_union_types.each do |sub_type|
      sub_type_cond = match_any_type_id(sub_type, type_id)
      result = result ? or(result, sub_type_cond) : sub_type_cond
    end
    ret result.not_nil!
  end

  private def create_match_fun_body(type : VirtualType, type_id)
    min, max = @llvm_id.min_max_type_id(type.base_type).not_nil!
    ret(
      and(
        builder.icmp(LLVM::IntPredicate::SGE, type_id, int(min)),
        builder.icmp(LLVM::IntPredicate::SLE, type_id, int(max))
      )
    )
  end

  private def create_match_fun_body(type : VirtualMetaclassType, type_id)
    result = equal? type_id(type), type_id
    type.each_concrete_type do |sub_type|
      sub_type_cond = equal? type_id(sub_type), type_id
      result = or(result, sub_type_cond)
    end
    ret result
  end

  private def create_match_fun_body(type, type_id)
    result = nil
    type.each_concrete_type do |sub_type|
      sub_type_cond = equal? type_id(sub_type), type_id
      result = result ? or(result, sub_type_cond) : sub_type_cond
    end
    ret result.not_nil!
  end
end
