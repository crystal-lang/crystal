struct Crystal::ExhaustivenessChecker
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

    if cond.is_a?(TupleLiteral)
      check_tuple_exp(node, cond)
    else
      check_single_exp(node, cond)
    end
  end

  private def check_single_exp(node, cond)
    cond_type = cond.type?

    # No type on condition means we couldn't type it so we can't
    # check exhasutiveness.
    return unless cond_type

    # Compute all types that we must cover.
    # We only take into account union types and single types,
    # never virtual types because these can be extended.
    cond_types = expand_types(cond_type)

    # Compute all the targets that we must cover
    targets = cond_types.map { |cond_type| compute_target(cond_type) }

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
        pattern_info = when_pattern_info(when_cond)
        pattern = pattern_info.pattern

        if !pattern_info.pattern_is_type
          all_patterns_are_types = false
        end

        if pattern
          targets.each &.cover(pattern)
        else
          all_provable_patterns = false
        end
      end
    end

    targets.reject! &.covered?

    # If we covered all types, we are done.
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

  private def check_tuple_exp(node, cond)
    elements = cond.elements

    # No type on condition means we couldn't type it so we can't
    # check exhasutiveness.
    return unless elements.all? &.type?

    element_types = elements.map &.type

    all_expanded_types = element_types.map do |element_type|
      expand_types(element_type)
    end

    # Compute all the targets that we must cover
    targets = compute_targets(all_expanded_types)

    # Are all patterns Path types?
    all_patterns_are_types = true

    # Are all patterns things that we can handle?
    # For example an integer literal is something that we don't
    # take into account for exhaustiveness.
    all_provable_patterns = true

    # Is any type a @[Flags] enum?
    has_flags_enum = all_expanded_types.any? &.any? { |type| type.is_a?(EnumType) && type.flags? }

    # Start checking each `when`...
    node.whens.each do |a_when|
      a_when.conds.each do |when_cond|
        if when_cond.is_a?(TupleLiteral)
          pattern_infos = when_cond.elements.map do |when_cond_exp|
            when_pattern_info(when_cond_exp)
          end

          if !pattern_infos.all? &.pattern_is_type
            all_patterns_are_types = false
          end

          if pattern_infos.all? &.pattern
            patterns = pattern_infos.map &.pattern.not_nil!
            targets.each &.cover(patterns, 0)
          else
            all_provable_patterns = false
          end
        else
          # TODO ...
        end
      end
    end

    targets.reject! &.reject_covered!

    # If we covered all types, we are done.
    return if targets.empty?

    # If all patterns are stuff we can handle, show the missing cases
    if all_provable_patterns
      missing_cases = targets
        .flat_map(&.missing_cases)
        .map { |cases| "{#{cases}}" }
        .join(", ")

      @program.report_warning(node, <<-MSG)
      case is not exhaustive.

      Missing cases: #{missing_cases}
      MSG
      return
    end

    # Otherwise we can't prove exhaustiveness and an `else` clause is required
    @program.report_warning(node, <<-MSG)
      can't prove case is exhaustive.

      Please add an `else` clause.
      MSG
  end

  private def compute_targets(type_groups)
    type_groups.first.map do |type|
      compute_target(type).tap do |target|
        target.add_subtargets(type_groups, 1)
      end
    end
  end

  # Retuens an array of all the types inside `type`:
  # for unions it's all the union types, otherwise it's just that type.
  private def expand_types(type)
    if type.is_a?(UnionType)
      type.union_types.map(&.devirtualize.as(Type))
    else
      [type.devirtualize]
    end
  end

  private def compute_target(type)
    ExhaustivenessChecker.compute_target(type)
  end

  def self.compute_target(type)
    case type
    when BoolType
      BoolTarget.new(type)
    when EnumType
      if type.flags?
        TypeTarget.new(type)
      else
        EnumTarget.new(type)
      end
    else
      TypeTarget.new(type)
    end
  end

  record PatternInfo,
    pattern : Pattern?,
    pattern_is_type : Bool do
    def self.empty
      new(pattern: nil, pattern_is_type: false)
    end
  end

  private def when_pattern_info(when_cond) : PatternInfo
    case when_cond
    when Path
      # In case of a Path that points to a type,
      # remove that type from the types we must cover
      if !when_cond.syntax_replacement && !when_cond.target_const &&
         when_cond.type?
        return PatternInfo.new(
          pattern: TypePattern.new(when_cond.type.devirtualize),
          pattern_is_type: true
        )
      end

      # If we find a constant that doesn't point to a type (so a value),
      # if it's an enum member, try to remove it from the targets.
      if (target_const = when_cond.target_const) &&
         target_const.namespace.is_a?(EnumType)
        return PatternInfo.new(
          pattern: EnumMemberPattern.new(target_const),
          pattern_is_type: false,
        )
      end

      PatternInfo.empty
    when Call
      # Check if it's something like `.foo?` to remove that member from the ones
      # we must cover.
      # Note: a user could override the meaning of such methods.
      # In the future it would be wise to mark these as non-redefinable
      # so this checks are sounds.
      if when_cond.obj.is_a?(ImplicitObj) &&
         when_cond.args.empty? && when_cond.named_args.nil? &&
         !when_cond.block && !when_cond.block_arg && when_cond.name.ends_with?('?')
        PatternInfo.new(
          pattern: EnumMemberNamePattern.new(when_cond.name.rchop),
          pattern_is_type: false,
        )
      else
        PatternInfo.empty
      end
    when BoolLiteral
      PatternInfo.new(
        pattern: BoolPattern.new(when_cond.value),
        pattern_is_type: false,
      )
    when NilLiteral
      PatternInfo.new(
        pattern: TypePattern.new(@program.nil_type),
        pattern_is_type: false,
      )
    else
      PatternInfo.empty
    end
  end

  # A type pattern is when you do `when Type`
  record TypePattern, type : Type

  # An enum member pattern is when you do `when Foo::Bar`
  # and `Bar` is an enum member of `Foo`
  record EnumMemberPattern, member : Const

  # An enum member pattern is when you do `when .foo?`
  record EnumMemberNamePattern, name : String

  # A bool pattern is when you do `when true` or `when false`
  record BoolPattern, value : Bool

  alias Pattern = TypePattern | EnumMemberPattern | EnumMemberNamePattern | BoolPattern

  # A target to check for exhaustiveness
  #
  # Every target can also have subtargets, used when matching against a tuple literal.
  # For example, the BoolTarget will have one subtarget for the value `false` and
  # one for the value `true`. When a pattern like `{false, ...}` is passed to it,
  # only patterns for the `false` subtarget will be covered.
  abstract class Target
    # The type this target is based on.
    getter type

    def initialize(@type : Type)
      @type_covered = false
    end

    # Tries to cover this target with the given pattern.
    # By default, a TypePatteren will cover a target.
    # Other, more specific, patterns will partially cover a target.
    def cover(pattern : Pattern) : Nil
      if pattern.is_a?(TypePattern)
        if @type.implements?(pattern.type)
          @type_covered = true
        end
      end
    end

    # Covers this target and subsequent subtargets with the patterns starting
    # at index.
    abstract def cover(patterns : Array(Pattern), index : Int32) : Nil

    # Removes covered subtargets from this target, and returns whether
    # this target ended up being entirely covered.
    abstract def reject_covered! : Bool

    # Was this target covered?
    abstract def covered? : Bool

    # What are the cases that we didn't cover?
    abstract def missing_cases : Array(String)

    # Add subtargets for the given type groups, starting at index.
    abstract def add_subtargets(type_groups : Array(Array(Type)), index : Int32) : Nil
  end

  # A bool target. Subtargets are the `false` and `true` literals.
  class BoolTarget < Target
    property? found_true = false
    property? found_false = false
    property! subtargets : Hash(Bool, Target)

    def cover(pattern : Pattern) : Nil
      super

      if pattern.is_a?(BoolPattern)
        if pattern.value
          @found_true = true
        else
          @found_false = true
        end
      end
    end

    def cover(patterns : Array(Pattern), index : Int32) : Nil
      if index == patterns.size - 1
        cover(patterns.last)
        return
      end

      pattern = patterns[index]
      case pattern
      when TypePattern
        if @type.implements?(pattern.type)
          subtargets.each do |key, subtarget|
            subtarget.cover(patterns, index + 1)
          end
        end
      when BoolPattern
        subtargets[pattern.value].cover(patterns, index + 1)
      else
        # Not a matching pattern
      end
    end

    def reject_covered! : Bool
      if subtargets = @subtargets
        subtargets.reject! { |b, target| target.reject_covered! }
        subtargets.all? { |b, target| target.covered? }
      else
        covered?
      end
    end

    def covered? : Bool
      if subtargets = @subtargets
        subtargets.all? { |b, target| target.covered? }
      else
        @type_covered || found_true? && found_false?
      end
    end

    def missing_cases : Array(String)
      if subtargets = @subtargets
        subtargets.flat_map do |bool, target|
          target.missing_cases.map do |missing_case|
            "#{bool}, #{missing_case}"
          end
        end
      else
        missing_cases = [] of String
        missing_cases << "false" unless found_false?
        missing_cases << "true" unless found_true?
        missing_cases
      end
    end

    def add_subtargets(type_groups : Array(Array(Type)), index : Int32) : Nil
      return if index >= type_groups.size

      subtargets = @subtargets = {} of Bool => Target

      type_groups[index].each do |expanded_type|
        {true, false}.each do |bool_value|
          target = ExhaustivenessChecker.compute_target(expanded_type)
          target.add_subtargets(type_groups, index + 1)
          subtargets[bool_value] = target
        end
      end
    end
  end

  # An enum target. Subtargets are the enum members.
  class EnumTarget < Target
    getter members : Array(Const)

    @original_members_size : Int32

    property! subtargets : Hash(Const, Target)

    def initialize(type)
      super
      @members = type.types.values.select(Const)
      @original_members_size = @members.size
    end

    def cover(pattern : Pattern) : Nil
      super

      case pattern
      when EnumMemberPattern
        @members.delete(pattern.member)
      when EnumMemberNamePattern
        @members.reject! { |member| member.name.underscore == pattern.name }
      else
        # Not interested in other patterns
      end
    end

    def cover(patterns : Array(Pattern), index : Int32) : Nil
      if index == patterns.size - 1
        cover(patterns.last)
        return
      end

      pattern = patterns[index]
      case pattern
      when TypePattern
        if @type.implements?(pattern.type)
          subtargets.each do |key, subtarget|
            subtarget.cover(patterns, index + 1)
          end
        end
      when EnumMemberPattern
        subtargets.each do |member, target|
          if member == pattern.member
            target.cover(patterns, index + 1)
          end
        end
      when EnumMemberNamePattern
        subtargets.each do |member, target|
          if member.name.underscore == pattern.name
            target.cover(patterns, index + 1)
          end
        end
      else
        # Not a matching pattern
      end
    end

    def reject_covered! : Bool
      if subtargets = @subtargets
        subtargets.reject! { |c, target| target.reject_covered! }
        subtargets.all? { |c, target| target.covered? }
      else
        covered?
      end
    end

    def covered? : Bool
      if subtargets = @subtargets
        subtargets.all? { |c, target| target.covered? }
      else
        @type_covered || @members.empty?
      end
    end

    def missing_cases : Array(String)
      if subtargets = @subtargets
        subtargets.flat_map do |const, target|
          target.missing_cases.map do |missing_case|
            "#{const}, #{missing_case}"
          end
        end
      else
        if @original_members_size == @members.size
          [type.to_s]
        else
          @members.map(&.to_s)
        end
      end
    end

    def add_subtargets(type_groups : Array(Array(Type)), index : Int32) : Nil
      return if index >= type_groups.size

      subtargets = @subtargets = {} of Const => Target

      type_groups[index].each do |expanded_type|
        @members.each do |member|
          target = ExhaustivenessChecker.compute_target(expanded_type)
          target.add_subtargets(type_groups, index + 1)
          subtargets[member] = target
        end
      end
    end
  end

  # Any other target is a type target. The target to cover is the type itself.
  class TypeTarget < Target
    property! subtargets : Array(Target)

    def cover(patterns : Array(Pattern), index : Int32) : Nil
      if index == patterns.size - 1
        cover(patterns.last)
        return
      end

      pattern = patterns[index]
      case pattern
      when TypePattern
        if @type.implements?(pattern.type)
          subtargets.each &.cover(patterns, index + 1)
        end
      else
        # Not a matching pattern
      end
    end

    def reject_covered! : Bool
      if subtargets = @subtargets
        subtargets.reject! &.reject_covered!
        subtargets.all? &.covered?
      else
        covered?
      end
    end

    def covered? : Bool
      if subtargets = @subtargets
        subtargets.all? &.covered?
      else
        @type_covered
      end
    end

    def missing_cases : Array(String)
      if subtargets = @subtargets
        subtargets.flat_map do |target|
          target.missing_cases.map do |missing_case|
            "#{type}, #{missing_case}"
          end
        end
      else
        [type.to_s]
      end
    end

    def add_subtargets(type_groups : Array(Array(Type)), index : Int32) : Nil
      return if index >= type_groups.size

      subtargets = @subtargets = [] of Target

      type_groups[index].each do |expanded_type|
        target = ExhaustivenessChecker.compute_target(expanded_type)
        target.add_subtargets(type_groups, index + 1)
        subtargets << target
      end
    end
  end
end
