class Crystal::CodeGenVisitor < Crystal::Visitor
  def match_type_id(type, restriction : Program, type_id)
    llvm_true
  end

  def match_type_id(type : UnionType | HierarchyType | HierarchyMetaclassType, restriction, type_id)
    match_any_type_id(restriction, type_id)
  end

  def match_type_id(type, restriction, type_id)
    equal? type_id(restriction), type_id
  end

  def match_any_type_id(type, type_id)
    # Special case: if the type is Object+ we want to match against Reference+,
    # because Object+ can only mean a Reference type (so we exclude Nil, for example).
    type = @mod.reference.hierarchy_type if type == @mod.object.hierarchy_type

    case type
    when UnionType
      match_any_type_id_with_function(type, type_id)
    when HierarchyMetaclassType
      match_any_type_id_with_function(type, type_id)
    when HierarchyType
      if type.base_type.subclasses.empty?
        equal? type_id(type.base_type), type_id
      else
        match_any_type_id_with_function(type, type_id)
      end
    else
      equal? type_id(type), type_id
    end
  end

  def match_any_type_id_with_function(type, type_id)
    match_fun_name = "~match<#{type}>"
    func = @main_mod.functions[match_fun_name]? || create_match_fun(match_fun_name, type)
    func = check_main_fun match_fun_name, func
    return call func, [type_id] of LibLLVM::ValueRef
  end

  def create_match_fun(name, type)
    define_main_function(name, ([LLVM::Int32] of LibLLVM::TypeRef), LLVM::Int1) do |func|
      type_id = func.get_param(0)
      create_match_fun_body(type, type_id)
    end
  end

  def create_match_fun_body(type : UnionType, type_id)
    result = nil
    type.union_types.each do |sub_type|
      sub_type_cond = match_any_type_id(sub_type, type_id)
      result = result ? or(result, sub_type_cond) : sub_type_cond
    end
    ret result.not_nil!
  end

  def create_match_fun_body(type : HierarchyType, type_id)
    min_max = @llvm_id.min_max_type_id(type.base_type).not_nil!
    ret(
      and (builder.icmp LibLLVM::IntPredicate::SGE, type_id, int(min_max[0])),
                   (builder.icmp LibLLVM::IntPredicate::SLE, type_id, int(min_max[1]))
                )
  end

  def create_match_fun_body(type, type_id)
    result = nil
    type.each_concrete_type do |sub_type|
      sub_type_cond = equal? type_id(sub_type), type_id
      result = result ? or(result, sub_type_cond) : sub_type_cond
    end
    ret result.not_nil!
  end
end
