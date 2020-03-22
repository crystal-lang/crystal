struct Crystal::ExhaustivenessChecker
  # A target to check for exhaustiveness
  abstract class Target
    # The type this target is based on.
    getter type

    def initialize(@type : Type)
    end

    # Was this target covered?
    abstract def covered? : Bool

    # What are the cases that we didn't cover?
    abstract def missing_cases : Array(String)
  end

  # A bool target. Subtargets are the `false` and `true` literals.
  class BoolTarget < Target
    property? found_true = false
    property? found_false = false

    def covered? : Bool
      found_true? && found_false?
    end

    def missing_cases : Array(String)
      missing_cases = [] of String
      missing_cases << "false" unless found_false?
      missing_cases << "true" unless found_true?
      missing_cases
    end
  end

  # An enum target. Subtargets are the enum members.
  class EnumTarget < Target
    getter members : Array(Const)

    @original_members_size : Int32

    def initialize(type)
      super
      @members = type.types.values.select(Const)
      @original_members_size = @members.size
    end

    def covered? : Bool
      @members.empty?
    end

    def missing_cases : Array(String)
      if @original_members_size == @members.size
        [type.to_s]
      else
        @members.map(&.to_s)
      end
    end
  end

  # Any other target is a type target. The target to cover is the type itself.
  class TypeTarget < Target
    def covered? : Bool
      false
    end

    def missing_cases : Array(String)
      [type.to_s]
    end
  end

  def initialize(@program : Program)
  end

  def check(node : Case)
    # If there's an else clause we don't need to check anything
    return if node.else

    cond = node.cond

    unless cond
      @program.report_warning(node,
        "case without condition must have an `else` clause.")
      return
    end

    # No condition means it's just like a series of if/else
    return unless cond

    # TODO: check exhaustiveness over a tuple
    return if cond.is_a?(TupleLiteral)

    cond_type = cond.type?

    # No type on condition means we couldn't type it so we can't
    # check of exhasutiveness.
    return unless cond_type

    # Compute all types that we must cover.
    # We only take into account union types and single types,
    # never virtual types because these can be extended.
    if cond_type.is_a?(UnionType)
      cond_types = cond_type.union_types.dup.map(&.devirtualize.as(Type))
    else
      cond_types = [cond_type.devirtualize]
    end

    # Compute all the targets that we must cover
    targets = cond_types.map do |cond_type|
      if cond_type.is_a?(BoolType)
        BoolTarget.new(cond_type)
      elsif cond_type.is_a?(EnumType) && !cond_type.flags?
        EnumTarget.new(cond_type)
      else
        TypeTarget.new(cond_type)
      end
    end

    # Are all patterns Path types?
    all_patterns_are_types = true

    # Are all patterns things that we can handle?
    # For example an integer literal is something that we don't
    # take into account for exhaustiveness.
    all_provable_patterns = true

    # Is any type a @[Flags] enum?
    has_flags_enum = cond_types.any? { |type| type.is_a?(EnumType) && type.flags? }

    # Start checking each `when`...
    node.whens.each do |a_when|
      a_when.conds.each do |when_cond|
        case when_cond
        when Path
          # In case of a Path that points to a type,
          # remove that type from the types we must cover
          if !when_cond.syntax_replacement && !when_cond.target_const &&
             when_cond.type?
            remove_type_from_targets(targets, when_cond.type)
            next
          end

          all_patterns_are_types = false

          # If we find a constant that doesn't point to a type (so a value),
          # if it's an enum member, try to remove it from the targets.
          if (target_const = when_cond.target_const) &&
             target_const.namespace.is_a?(EnumType)
            remove_enum_member_from_targets(targets, target_const)
            next
          end

          all_provable_patterns = false
        when Call
          all_patterns_are_types = false

          # Check if it's something like `.foo?` to remove that member from the ones
          # we must cover.
          # Note: a user could override the meaning of such methods.
          # In the future it would be wise to mark these as non-redefinable
          # so this checks are sounds.
          if when_cond.obj.is_a?(ImplicitObj) &&
             when_cond.args.empty? && when_cond.named_args.nil? &&
             !when_cond.block && !when_cond.block_arg && when_cond.name.ends_with?('?')
            remove_enum_member_name_from_targets(targets, when_cond.name.rchop)
          else
            all_provable_patterns = false
          end
        when BoolLiteral
          all_patterns_are_types = false

          remove_bool_literal_from_targets(targets, when_cond.value)
        when NilLiteral
          all_patterns_are_types = false

          # A nil literal is the same as matching the Nil type
          remove_type_from_targets(targets, @program.nil_type)
        else
          all_patterns_are_types = false
          all_provable_patterns = false
        end
      end
    end

    targets.reject! &.covered?

    # If we covered all types, we are done.
    # This works even when matching against Bool or Enum.
    return if targets.empty?

    if targets.all?(&.is_a?(TypeTarget)) && all_patterns_are_types
      @program.report_warning(node, <<-MSG)
        case is not exhaustive.

        Missing types: #{targets.map(&.type).join(", ")}
        MSG
      return
    end

    single_target = targets.size == 1 ? targets.first : nil

    case single_target
    when BoolTarget
      @program.report_warning(node, <<-MSG)
        case is not exhaustive.

        Missing cases: #{single_target.missing_cases.join(", ")}
        MSG
      return
    when EnumTarget
      @program.report_warning(node, <<-MSG)
        case is not exhaustive for enum #{single_target.type}.

        Missing members: #{single_target.members.map(&.name).join(", ")}
        MSG
      return
    else
      # No specific error messages for non-single types
    end

    if all_provable_patterns && !has_flags_enum
      @program.report_warning(node, <<-MSG)
        case is not exhaustive.

        Missing cases: #{targets.flat_map(&.missing_cases).join(", ")}
        MSG
      return
    end

    # Otherwise we can't prove exhaustiveness and an `else` clause is required
    @program.report_warning(node, <<-MSG)
      can't prove case is exhaustive.

      Please add an `else` clause.
      MSG
  end

  private def remove_type_from_targets(targets, type : Type)
    type = type.devirtualize
    targets.reject! { |target| target.type.implements?(type) }
  end

  private def remove_enum_member_from_targets(targets, member)
    targets.each do |target|
      if target.is_a?(EnumTarget)
        target.members.delete(member)
      end
    end
  end

  private def remove_enum_member_name_from_targets(targets, name)
    targets.each do |target|
      if target.is_a?(EnumTarget)
        target.members.reject! { |member| member.name.underscore == name }
      end
    end
  end

  private def remove_bool_literal_from_targets(targets, bool)
    targets.each do |target|
      if target.is_a?(BoolTarget)
        if bool
          target.found_true = true
        else
          target.found_false = true
        end
      end
    end
  end
end
