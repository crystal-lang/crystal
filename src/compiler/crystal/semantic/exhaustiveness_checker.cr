struct Crystal::ExhaustivenessChecker
  def initialize(@program : Program)
  end

  def check(node : Case)
    cond = node.cond.not_nil!

    if cond.is_a?(TupleLiteral)
      check_tuple_exp(node, cond)
    else
      check_single_exp(node, cond)
    end
  end

  private def check_single_exp(node, cond)
    cond_type = cond.type?

    # No type on condition means we couldn't type it so we can't
    # check exhaustiveness.
    return unless cond_type

    # Compute all types that we must cover.
    # We only take into account union types and single types,
    # never virtual types because these can be extended.
    cond_types = expand_types(cond_type)

    # Compute all the targets that we must cover
    targets = cond_types.map { |cond_type| compute_target(cond_type) }

    # Is any type a @[Flags] enum?
    flags_enum = cond_types.find { |type| type.is_a?(EnumType) && type.flags? }

    # Are all patterns Path types?
    all_patterns_are_types = true

    # Start checking each `when`...
    node.whens.each do |a_when|
      a_when.conds.each do |when_cond|
        pattern = when_pattern(when_cond)

        unless pattern.is_a?(TypePattern)
          all_patterns_are_types = false
        end

        targets.each &.cover(pattern)
      end
    end

    targets.reject! &.covered?

    # If we covered all types, we are done.
    return if targets.empty?

    if targets.all?(TypeTarget) && all_patterns_are_types
      node.raise <<-MSG
        case is not exhaustive.

        Missing types:
         - #{targets.map(&.type).join("\n - ")}
        MSG
    end

    single_target = targets.size == 1 ? targets.first : nil

    case single_target
    when BoolTarget
      node.raise <<-MSG
        case is not exhaustive.

        Missing cases:
         - #{single_target.missing_cases.join("\n - ")}
        MSG
    when EnumTarget
      node.raise <<-MSG
      case is not exhaustive for enum #{single_target.type}.

      Missing members:
       - #{single_target.members.map(&.name).join("\n - ")}
      MSG
    else
      # No specific error messages for non-single types
    end

    msg = <<-MSG
      case is not exhaustive.

      Missing cases:
       - #{targets.flat_map(&.missing_cases).join("\n - ")}
      MSG

    if flags_enum
      msg += "\n\n" + flags_enum_message(flags_enum)
    end

    node.raise msg
  end

  private def check_tuple_exp(node, cond)
    elements = cond.elements

    # No type on condition means we couldn't type it so we can't
    # check exhaustiveness.
    return unless elements.all? &.type?

    element_types = elements.map &.type

    all_expanded_types = element_types.map do |element_type|
      expand_types(element_type)
    end

    # Is any type a @[Flags] enum?
    flags_enum = nil
    all_expanded_types.each do |types|
      types.each do |type|
        if type.is_a?(EnumType) && type.flags?
          flags_enum = type
          break
        end
      end
      break if flags_enum
    end

    targets = compute_targets(all_expanded_types)

    # Start checking each `when`...
    node.whens.each do |a_when|
      a_when.conds.each do |when_cond|
        if when_cond.is_a?(TupleLiteral)
          patterns = when_cond.elements.map do |when_cond_exp|
            when_pattern(when_cond_exp)
          end

          targets.each &.cover(patterns, 0)
        else
          # Not a tuple literal so we don't care
          # TODO: one could put `Tuple` or `Object` here and that would make
          # the entire tuple match, but who would do that?
          # We can do it, but it has very low priority.
        end
      end
    end

    targets.reject! &.reject_covered!

    # If we covered all types, we are done.
    return if targets.empty?

    missing_cases = targets
      .flat_map(&.missing_cases)
      .map { |cases| "{#{cases}}" }
      .join("\n - ")

    msg = <<-MSG
      case is not exhaustive.

      Missing cases:
       - #{missing_cases}
      MSG

    if flags_enum
      msg += "\n\n" + flags_enum_message(flags_enum)
    end

    node.raise msg
  end

  private def flags_enum_message(flags_enum)
    <<-MSG
      Note that @[Flags] enum can't be proved to be exhaustive by matching against enum members.
      In particular, the enum #{flags_enum} can't be proved to be exhaustive like that.
      MSG
  end

  private def compute_targets(type_groups)
    type_groups.first.map do |type|
      compute_target(type).tap do |target|
        target.add_subtargets(type_groups, 1)
      end
    end
  end

  # Returns an array of all the types inside `type`:
  # for unions it's all the union types, otherwise it's just that type.
  private def expand_types(type)
    if type.is_a?(UnionType)
      type.union_types.map(&.devirtualize.as(Type))
    else
      [type.devirtualize]
    end
  end

  private def compute_target(type : Type)
    ExhaustivenessChecker.compute_target(type)
  end

  def self.compute_target(type : Type)
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

  private def when_pattern(when_cond) : Pattern?
    case when_cond
    when Path
      if !when_cond.syntax_replacement && !when_cond.target_const &&
         when_cond.type?
        # In case of a Path that points to a type,
        # remove that type from the types we must cover
        TypePattern.new(when_cond.type.devirtualize)
      elsif (target_const = when_cond.target_const) &&
            target_const.namespace.is_a?(EnumType)
        # If we find a constant that doesn't point to a type (so a value),
        # if it's an enum member, try to remove it from the targets.
        EnumMemberPattern.new(target_const)
      else
        when_cond.raise "can't use constant values in exhaustive case, only constant types"
      end
    when Generic
      TypePattern.new(when_cond.type.devirtualize)
    when Call
      obj = when_cond.obj

      # Check if it's something like `.foo?` to remove that member from the ones
      # we must cover.
      # Note: a user could override the meaning of such methods.
      # In the future it would be wise to mark these as non-redefinable
      # so this checks are sounds.
      if obj.is_a?(ImplicitObj) && when_cond.name.ends_with?('?')
        EnumMemberNamePattern.new(when_cond.name.rchop)
      elsif obj.is_a?(Path) && when_cond.name == "class"
        TypePattern.new(obj.type.metaclass.devirtualize)
      elsif obj.is_a?(Generic) && when_cond.name == "class"
        TypePattern.new(obj.type.metaclass.devirtualize)
      else
        raise "Bug: unknown pattern in exhaustive case"
      end
    when BoolLiteral
      BoolPattern.new(when_cond.value)
    when NilLiteral
      TypePattern.new(@program.nil_type)
    when Underscore
      UnderscorePattern.new
    else
      raise "Bug: unknown pattern in exhaustive case"
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

  # An underscore pattern is when you do `when {.., _}` (only in tuple literals)
  record UnderscorePattern

  alias Pattern = TypePattern | EnumMemberPattern | EnumMemberNamePattern | BoolPattern | UnderscorePattern

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
    # By default, a TypePattern will cover a target.
    # Other, more specific, patterns will partially cover a target.
    def cover(pattern : Pattern) : Nil
      case pattern
      when TypePattern
        if @type.implements?(pattern.type)
          @type_covered = true
        end
      when UnderscorePattern
        @type_covered = true
      when EnumMemberPattern, EnumMemberNamePattern, BoolPattern
        # No cover
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
    property! subtargets : Hash(Bool, Array(Target))

    def cover(pattern : Pattern) : Nil
      super

      case pattern
      when BoolPattern
        if pattern.value
          @found_true = true
        else
          @found_false = true
        end
      when UnderscorePattern
        @found_true = true
        @found_false = true
      when TypePattern, EnumMemberPattern, EnumMemberNamePattern
        # No cover
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
          subtargets.each_value &.each &.cover(patterns, index + 1)
        end
      when BoolPattern
        subtargets[pattern.value].each &.cover(patterns, index + 1)
      when UnderscorePattern
        subtargets.each_value &.each &.cover(patterns, index + 1)
      when EnumMemberPattern, EnumMemberNamePattern
        # No cover
      end
    end

    def reject_covered! : Bool
      if subtargets = @subtargets
        subtargets.reject! do |b, targets|
          targets.reject! &.reject_covered!
          targets.all? &.covered?
        end
        subtargets.all? { |b, targets| targets.all? &.covered? }
      else
        covered?
      end
    end

    def covered? : Bool
      if subtargets = @subtargets
        subtargets.all? { |b, targets| targets.all? &.covered? }
      else
        @type_covered || (found_true? && found_false?)
      end
    end

    def missing_cases : Array(String)
      if subtargets = @subtargets
        # First get all missing cases for each bool value
        missing_cases_per_bool = subtargets.to_h do |bool, targets|
          {bool, targets.flat_map &.missing_cases}
        end

        gathered_missing_cases = [] of String

        # See if a case is missing for both false and true: show it as Bool in that case
        missing_cases_per_bool.values.flatten.uniq!.each do |missing_case|
          if {true, false}.all? { |bool| missing_cases_per_bool[bool]?.try &.includes?(missing_case) }
            gathered_missing_cases << "Bool, #{missing_case}"
            {true, false}.each { |bool| missing_cases_per_bool[bool]?.try &.delete(missing_case) }
          end
        end

        missing_cases_per_bool.each do |bool, missing_cases|
          missing_cases.each do |missing_case|
            gathered_missing_cases << "#{bool}, #{missing_case}"
          end
        end

        gathered_missing_cases
      else
        missing_cases = [] of String
        missing_cases << "false" unless found_false?
        missing_cases << "true" unless found_true?
        if missing_cases.size == 2
          missing_cases.clear
          missing_cases << "Bool"
        end
        missing_cases
      end
    end

    def add_subtargets(type_groups : Array(Array(Type)), index : Int32) : Nil
      return if index >= type_groups.size

      subtargets = @subtargets = {} of Bool => Array(Target)

      {true, false}.each do |bool_value|
        subtargets[bool_value] = type_groups[index].map do |expanded_type|
          target = ExhaustivenessChecker.compute_target(expanded_type)
          target.add_subtargets(type_groups, index + 1)
          target
        end
      end
    end
  end

  # An enum target. Subtargets are the enum members.
  class EnumTarget < Target
    getter members : Array(Const)

    @original_members_size : Int32

    property! subtargets : Hash(Const, Array(Target))

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
      when UnderscorePattern
        @members.clear
      when TypePattern, BoolPattern
        # No cover
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
          subtargets.each_value &.each &.cover(patterns, index + 1)
        end
      when EnumMemberPattern
        subtargets.each do |member, targets|
          if member == pattern.member
            targets.each &.cover(patterns, index + 1)
          end
        end
      when EnumMemberNamePattern
        subtargets.each do |member, targets|
          if member.name.underscore == pattern.name
            targets.each &.cover(patterns, index + 1)
          end
        end
      when UnderscorePattern
        subtargets.each_value &.each &.cover(patterns, index + 1)
      when BoolPattern
        # No cover
      end
    end

    def reject_covered! : Bool
      if subtargets = @subtargets
        subtargets.reject! do |c, targets|
          targets.reject! &.reject_covered!
          targets.all? &.covered?
        end
        subtargets.all? { |c, targets| targets.all? &.covered? }
      else
        covered?
      end
    end

    def covered? : Bool
      if subtargets = @subtargets
        subtargets.all? { |c, targets| targets.all? &.covered? }
      else
        @type_covered || @members.empty?
      end
    end

    def missing_cases : Array(String)
      if subtargets = @subtargets
        # First get all missing cases for each member
        missing_cases_per_member = subtargets.to_h do |member, targets|
          {member, targets.flat_map &.missing_cases}
        end

        gathered_missing_cases = [] of String

        # See if a case is missing for all members: show it as the enum name in that case
        missing_cases_per_member.values.flatten.uniq!.each do |missing_case|
          if @members.all? { |member| missing_cases_per_member[member]?.try &.includes?(missing_case) }
            gathered_missing_cases << "#{@type}, #{missing_case}"
            @members.each { |member| missing_cases_per_member[member]?.try &.delete(missing_case) }
          end
        end

        missing_cases_per_member.each do |member, missing_cases|
          missing_cases.each do |missing_case|
            gathered_missing_cases << "#{member}, #{missing_case}"
          end
        end

        gathered_missing_cases
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

      subtargets = @subtargets = {} of Const => Array(Target)

      @members.each do |member|
        subtargets[member] = type_groups[index].map do |expanded_type|
          target = ExhaustivenessChecker.compute_target(expanded_type)
          target.add_subtargets(type_groups, index + 1)
          target
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
      when UnderscorePattern
        subtargets.each &.cover(patterns, index + 1)
      when BoolPattern, EnumMemberPattern, EnumMemberNamePattern
        # No cover
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
