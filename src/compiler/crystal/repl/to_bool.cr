require "./compiler"

class Crystal::Repl::Compiler
  private def value_to_bool(node : ASTNode, type : NilType)
    put_false
  end

  private def value_to_bool(node : ASTNode, type : BoolType)
    # Nothing to do
  end

  private def value_to_bool(node : ASTNode, type : PointerInstanceType)
    pointer_is_not_null
  end

  private def value_to_bool(node : ASTNode, type : NilableType)
    pointer_is_not_null
  end

  private def value_to_bool(node : ASTNode, type : MixedUnionType)
    union_to_bool(sizeof_type(type))
  end

  private def value_to_bool(node : ASTNode, type : Type)
    node.raise "BUG: missing value_to_bool for #{type} (#{type.class})"
  end
end
