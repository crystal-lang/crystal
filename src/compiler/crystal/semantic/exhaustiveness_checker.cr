struct Crystal::ExhaustivenessChecker
  def initialize(@program : Program)
  end

  def check(node : Case)
    cond = node.cond

    # No condition means it's just like a series of if/else
    return unless cond

    # TODO: check exhaustiveness over a tuple
    return if cond.is_a?(TupleLiteral)

    # If there's an else clause we don't need to check anything
    return if node.else

    cond_type = cond.type?

    # No type on condition means we couldn't type it so we can't
    # check of exhasutiveness.
    return unless cond_type

    # Compute all types that we must cover.
    # We only take into account union types and single types,
    # never virtual types because these can be extended.
    #
    # Also remember whether it's just a single type we are checking
    # (useful for Bool and Enum later on).
    if cond_type.is_a?(UnionType)
      cond_types = cond_type.union_types.dup.map(&.devirtualize.as(Type))
      single_cond_type = nil
    else
      cond_types = [cond_type.devirtualize]
      single_cond_type = cond_type.devirtualize
    end

    # Are all when clauses types (paths)?
    all_whens_are_types = true

    # Did we find the `false` literal in any `when`?
    found_false = false

    # Did we find the `true` literal in any `when`?
    found_true = false

    # All enum members, as strings, in case we are matching against an enum
    enum_members = if single_cond_type.is_a?(EnumType)
                     single_cond_type.types.values.select(Const).map(&.name)
                   else
                     nil
                   end

    # Start checking each `when`...
    node.whens.each do |a_when|
      a_when.conds.each do |when_cond|
        # In case of a Path that points to a type,
        # remove that type from the types we must cover
        if when_cond.is_a?(Path) &&
           !when_cond.syntax_replacement && !when_cond.target_const &&
           when_cond.type?
          cond_types.reject! { |type| type.implements?(when_cond.type.devirtualize) }
          next
        end

        # At this point we are matching against other things than types/paths
        all_whens_are_types = false

        # If we are matching against an enum type and the Path denotes an enum member,
        # delete it from the members we must cover
        if when_cond.is_a?(Path) &&
           enum_members && single_cond_type.is_a?(EnumType) &&
           (target_const = when_cond.target_const)
          matching_member = single_cond_type.types.find { |k, v| v == target_const }
          if matching_member
            enum_members.delete(matching_member[1].name.to_s)
          end
        end

        case when_cond
        when Call
          # Check if it's something like `.foo?` to remove that member from the ones
          # we must cover.
          # Note: a user could override the meaning of such methods.
          # In the future it would be wise to mark these as non-redefinable
          # so this checks are sounds.
          if enum_members && when_cond.obj.is_a?(ImplicitObj) &&
             when_cond.args.empty? && when_cond.named_args.nil? &&
             !when_cond.block && !when_cond.block_arg && when_cond.name.ends_with?('?')
            enum_value = when_cond.name.rchop
            enum_members.reject! { |value| value.underscore == enum_value }
          end
        when BoolLiteral
          # Note that we found some bool literals
          if when_cond.value
            found_true = true
          else
            found_false = true
          end
        when NilLiteral
          # A nil literal is the same as matching the Nil type
          cond_types.reject! &.nil_type?
        else
          # Nothing to do
        end
      end
    end

    # If we found both `true` and `false` we covered Bool
    if found_false && found_true
      cond_types.delete(@program.bool)
    end

    # If we covered all types, we are done.
    # This works even when matching against Bool or Enum.
    return if cond_types.empty?

    # If we didn't cover all types, but we tried to match against types,
    # we know the user forgot some types.
    if all_whens_are_types
      @program.report_warning(node, <<-MSG)
        case is not exhaustive.

        Missing types: #{cond_types.join(", ")}
        MSG
      return
    end

    # Check the bool case
    if single_cond_type.is_a?(BoolType) && !(found_false && found_true)
      missing_cases = [] of String
      missing_cases << "false" unless found_false
      missing_cases << "true" unless found_true

      @program.report_warning(node, <<-MSG)
        case is not exhaustive.

        Missing cases: #{missing_cases.join(", ")}
        MSG
      return
    end

    # Check the enum case
    if single_cond_type.is_a?(EnumType) && enum_members
      # All enum members covered
      return if enum_members.empty?

      @program.report_warning(node, <<-MSG)
        case is not exhaustive for enum #{single_cond_type}.

        Missing members: #{enum_members.join(", ")}
        MSG
      return
    end

    # Otherwise we can't prove exhaustiveness and an `else` clause is required
    @program.report_warning(node, <<-MSG)
      can't prove case is exhaustive.

      Please add an `else` clause.
      MSG
  end
end
