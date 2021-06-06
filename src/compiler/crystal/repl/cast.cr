require "./compiler"

class Crystal::Repl::Compiler
  private def upcast(node : ASTNode, from : Type, to : Type)
    return if from == to

    upcast_distinct(node, from, to)
  end

  private def upcast_distinct(node : ASTNode, from : Type, to : MixedUnionType)
    put_in_union(type_id(from), aligned_sizeof_type(from), aligned_sizeof_type(to), node: node)
  end

  private def upcast_distinct(node : ASTNode, from : NilType, to : NilableType)
    # TODO: pointer sizes
    put_i64 0_i64, node: nil
  end

  private def upcast_distinct(node : ASTNode, from : Type, to : NilableType)
    # Nothing
  end

  private def upcast_distinct(node : ASTNode, from : NilType, to : NilableReferenceUnionType)
    # TODO: pointer sizes
    put_i64 0_i64, node: nil
  end

  private def upcast_distinct(node : ASTNode, from : Type, to : NilableReferenceUnionType)
    # Nothing
  end

  private def upcast_distinct(node : ASTNode, from : NonGenericClassType, to : VirtualType)
    # Nothing
  end

  private def upcast_distinct(node : ASTNode, from : NilType, to : NilableProcType)
    # This is Proc.new(Pointer(Void).null, Pointer(Void).null)
    put_i64 0, node: node
    put_i64 0, node: node
  end

  # TODO: remove these two because they are probably not needed
  private def upcast_distinct(node : ASTNode, from : NoReturnType, to : Type)
    # Nothing
  end

  private def upcast_distinct(node : ASTNode, from : Type, to : NoReturnType)
    # Nothing
  end

  private def upcast_distinct(node : ASTNode, from : Type, to : Type)
    node.raise "BUG: missing upcast_distinct from #{from} to #{to} (#{from.class} to #{to.class})"
  end

  private def downcast(node : ASTNode, from : Type, to : Type)
    return if from == to

    downcast_distinct(node, from, to)
  end

  private def downcast_distinct(node : ASTNode, from : MixedUnionType, to : Type)
    remove_from_union(aligned_sizeof_type(from), aligned_sizeof_type(to), node: nil)
  end

  private def downcast_distinct(node : ASTNode, from : NilableType, to : NonGenericClassType)
    # Nothing to do
  end

  # TODO: remove these two because they are probably not needed
  private def downcast_distinct(node : ASTNode, from : NoReturnType, to : Type)
    # Nothing
  end

  private def downcast_distinct(node : ASTNode, from : Type, to : NoReturnType)
    # Nothing
  end

  private def downcast_distinct(node : ASTNode, from : Type, to : Type)
    node.raise "BUG: missing downcast_distinct from #{from} to #{to} (#{from.class} to #{to.class})"
  end
end
