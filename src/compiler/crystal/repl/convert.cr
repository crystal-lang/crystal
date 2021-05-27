require "./compiler"

class Crystal::Repl::Compiler
  private def convert(node : ASTNode, from : Type, to : Type)
    return if from == to

    convert_distinct(node, from, to)
  end

  private def convert_distinct(node : ASTNode, from : Type, to : MixedUnionType)
    put_in_union(type_id(from), sizeof_type(from), sizeof_type(to), node: node)
  end

  private def convert_distinct(node : ASTNode, from : NilType, to : NilableType)
    # TODO: pointer sizes
    put_i64 0_i64, node: nil
  end

  private def convert_distinct(node : ASTNode, from : Type, to : NilableType)
    # Nothing
  end

  private def convert_distinct(node : ASTNode, from : NilType, to : NilableReferenceUnionType)
    # TODO: pointer sizes
    put_i64 0_i64, node: nil
  end

  private def convert_distinct(node : ASTNode, from : Type, to : NilableReferenceUnionType)
    # Nothing
  end

  private def convert_distinct(node : ASTNode, from : MixedUnionType, to : Type)
    remove_from_union(sizeof_type(from), sizeof_type(to), node: nil)
  end

  private def convert_distinct(node : ASTNode, from : NoReturnType, to : Type)
    # Nothing
  end

  private def convert_distinct(node : ASTNode, from : NilableType, to : NonGenericClassType)
    # Nothing to do
  end

  private def convert_distinct(node : ASTNode, from : Type, to : Type)
    node.raise "BUG: missing convert_distinct from #{from} to #{to} (#{from.class} to #{to.class})"
  end
end
