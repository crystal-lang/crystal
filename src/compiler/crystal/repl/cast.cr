require "./compiler"

class Crystal::Repl::Compiler
  private def upcast(node : ASTNode, from : Type, to : Type)
    return if from == to

    upcast_distinct(node, from, to)
  end

  private def upcast_distinct(node : ASTNode, from : MixedUnionType, to : MixedUnionType)
    # It might happen that some types inside the union `value_type` are not inside `target_type`,
    # for example with named tuple of same keys with different order. In that case we need cast
    # those value to the correct type before finally storing them in the target union.
    needs_union_value_cast = from.union_types.any? do |from_element|
      needs_value_cast_inside_union?(from_element, to)
    end

    if needs_union_value_cast # Compute the values that need a cast
      node.raise "BUG: missing upcast from #{from} to #{to}"
    end

    # Putting a smaller union type inside a bigger one is just extending the value
    difference = aligned_sizeof_type(to) - aligned_sizeof_type(from)
    if difference > 0
      push_zeros(difference, node: nil)
    end
  end

  private def needs_value_cast_inside_union?(value_type, union_type)
    # A type needs a special cast if:
    # 1. It's a tuple or named tuple
    # 2. It's not inside the target union
    # 3. There's a compatible type inside the target union
    return false unless value_type.is_a?(TupleInstanceType) || value_type.is_a?(NamedTupleInstanceType)
    !union_type.union_types.any?(&.==(value_type)) &&
      union_type.union_types.any? { |ut| value_type.implements?(ut) || ut.implements?(value_type) }
  end

  private def upcast_distinct(node : ASTNode, from : Type, to : MixedUnionType)
    put_in_union(type_id(from), aligned_sizeof_type(from), aligned_sizeof_type(to), node: nil)
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
    put_i64 0, node: nil
    put_i64 0, node: nil
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

  private def downcast_distinct(node : ASTNode, from : MixedUnionType, to : MixedUnionType)
    difference = aligned_sizeof_type(from) - aligned_sizeof_type(to)

    if difference > 0
      pop(difference, node: nil)
    end
  end

  private def downcast_distinct(node : ASTNode, from : MixedUnionType, to : Type)
    # TODO: tuples and named tuples

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
