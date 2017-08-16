class Crystal::Case
  property! scope : Type
  property! parent_visitor : MainVisitor

  # `nil` means 'not checked'. `true` means 'this case is exhaustive'. `false` means 'it cannot check exhaustiveness'.
  property? exhaustive : Bool? = nil

  def program
    scope.program
  end

  alias Pattern = Nil | Bool | Type

  # Run exhaustiveness-check and fix up expanded node.
  #
  # To define it as `#update` is needed to follow updating type after `case` statement.
  # For example:
  #
  # ```
  # a = 42
  #
  # loop do
  #   case! a
  #   when  Int32
  #   when  String
  #   end
  #
  #   a = "foo"
  # end
  # ```
  def update(from = nil)
    super

    return unless check_exhaustiveness?

    expansion = expanded.not_nil!
    self.unbind_from expansion

    is_exhaustive = check_exhaustiveness

    if exhaustive? != is_exhaustive
      last = expansion
      last = last.last if last.is_a?(Expressions)

      last_if = last.as(If)
      while (last_if_else = last_if.else).is_a?(If)
        last_if = last_if_else
      end

      last_if.unbind_from last_if.else

      if is_exhaustive
        new_last_if_else = Call.new(nil, "raise", args: [StringLiteral.new("BUG: invalid exhaustivness check")] of ASTNode, global: true).at(self)
      else
        new_last_if_else = Nop.new.at(self)
      end
      new_last_if_else.accept parent_visitor

      last_if.else = new_last_if_else
      last_if.bind_to new_last_if_else
      last_if.propagate
    end

    self.exhaustive = is_exhaustive
    self.bind_to expansion
  end

  # Here is an entry point of exhaustiveness-check implemtation.
  #
  # This result value meaning is:
  #
  #    - `true` means 'this case is exhaustive surely'.
  #    - `false` means 'it cannot check exhaustiveness of this case'.
  #
  # And, it raises compilation error when the compuler found non-exhaustive pattern(s).
  def check_exhaustiveness
    case_cond = self.cond.not_nil!

    if case_cond.is_a?(TupleLiteral)
      check_exhaustiveness_tuple case_cond
    else
      check_exhaustiveness_simple case_cond
    end
  end

  # Exhaustiveness-check for tuple e.g.
  #
  # ```
  # foo = true ? 42 : "foo"
  # bar = true ? 3.14 : :bar
  #
  # case! {foo, bar}
  # when  {Int32, _}
  #   p :left_int32
  # when  {_, Float64}
  #   p :right_float64
  # when  {String, Symbol}
  #   p :string_symbol
  # end
  # ```
  def check_exhaustiveness_tuple(case_tuple)
    element_patterns = case_tuple.elements.map do |case_cond|
      patterns = [] of Pattern
      return false unless calculate_patterns(case_cond) { |pattern| patterns << pattern }
      patterns
    end

    tuple_patterns = Set(Array(Pattern)).new
    Array.each_product(element_patterns) do |tuple_pattern|
      tuple_patterns << tuple_pattern
    end

    self.whens.each &.conds.each do |when_cond|
      case when_cond
      when Underscore
        # TODO: we really need this special case?
        return true
      when TupleLiteral
        next unless when_cond.elements.size == case_tuple.elements.size

        when_element_patterns = when_cond.elements.map_with_index do |when_cond, i|
          patterns = [] of Pattern
          check_exhaustiveness_step(element_patterns[i], when_cond) { |pattern| patterns << pattern }
          patterns
        end

        Array.each_product(when_element_patterns) do |tuple_pattern|
          tuple_patterns.delete tuple_pattern
        end
      else
        next
      end
    end

    return true if tuple_patterns.empty?

    message = String.build do |builder|
      builder << "found non-exhaustive pattern#{tuple_patterns.size > 1 ? "s" : ""}: "

      sorted_tuple_patterns = tuple_patterns.to_a.sort_by do |tuple_pattern|
        tuple_pattern.map do |pattern|
          case pattern
          when nil
            "0"
          when true
            "1"
          when false
            "2"
          else
            pattern.to_s
          end
        end
      end

      sorted_tuple_patterns.join(", ", builder) do |tuple_pattern|
        builder << "{"
        tuple_pattern.join(", ", builder) do |pattern|
          case pattern
          when Const
            builder << pattern
          when nil, Bool, Type
            builder << pattern.inspect
          end
        end
        builder << "}"
      end
    end

    case_tuple.raise message
  end

  # Exhaustiveness-check for simple condition e.g.
  #
  # ```
  # foo = true ? 42 : "foo"
  #
  # case! foo
  # when  Int32
  #   p :int32
  # when  String
  #   p :string
  # end
  # ```
  def check_exhaustiveness_simple(case_cond)
    patterns = Set(Pattern).new
    return false unless calculate_patterns(case_cond) { |pattern| patterns << pattern }

    self.whens.each &.conds.each do |when_cond|
      check_exhaustiveness_step(patterns, when_cond) do |pattern|
        patterns.delete pattern
      end
    end

    return true if patterns.empty?

    union = case_cond.type.is_a?(UnionType)

    message = String.build do |builder|
      builder << "found non-exhaustive pattern#{patterns.size > 1 ? "s" : ""}: "

      sorted_patterns = patterns.to_a.sort_by do |pattern|
        case pattern
        when nil
          "0"
        when true
          "1"
        when false
          "2"
        else
          pattern.to_s
        end
      end

      sorted_patterns.join(", ", builder) do |pattern|
        case pattern
        when Const
          builder << (union ? pattern : pattern.name)
        when nil, Bool, Type
          builder << pattern.inspect
        end
      end
    end

    case_cond.raise message
  end

  def calculate_patterns(case_cond)
    if (case_cond.is_a?(Var) || case_cond.is_a?(InstanceVar)) && !case_cond.type?
      case_cond.accept parent_visitor
      # Observe `case_cond` to follow updating variable type
      case_cond.add_observer self
    end
    return false unless case_cond_type = case_cond.type?

    case case_cond_type
    when UnionType
      # 'dup' is important to prevent changing this array value by mutable methods.
      types = case_cond_type.union_types.dup
    when EnumType
      types = [case_cond_type] of Type
    when program.bool, program.nil_type
      types = [case_cond_type] of Type
    else
      types = [case_cond_type] of Type
    end

    types.each do |type|
      case type
      when EnumType
        # A @[Flags] enum means a set of flags, so exhaustiveness check does not make sense.
        if type.flags?
          yield type
        else
          type.types.each_value do |t|
            yield t if t.is_a?(Const)
          end
        end
      when program.nil_type
        yield nil
      when program.bool
        yield true
        yield false
      else
        yield type
      end
    end

    true
  end

  def check_exhaustiveness_step(patterns, when_cond)
    case when_cond
    when Path
      type_or_const = scope.lookup_type_var?(when_cond, free_vars: parent_visitor.free_vars)
      if type_or_const.is_a?(Const)
        patterns.each do |const|
          if const.is_a?(Const) && const == type_or_const
            yield const
          end
        end
      elsif type_or_const.is_a?(Type)
        check_exhaustiveness_step_type(patterns, type_or_const) { |pattern| yield pattern }
      end
    when Generic
      if type = scope.lookup_type?(when_cond, free_vars: parent_visitor.free_vars)
        check_exhaustiveness_step_type(patterns, type) { |pattern| yield pattern }
      end
    when IsA
      if when_cond.obj.is_a?(ImplicitObj)
        if type = scope.lookup_type?(when_cond.const, free_vars: parent_visitor.free_vars)
          check_exhaustiveness_step_type(patterns, type) { |pattern| yield pattern }
        end
      end
    when Call
      if when_cond.obj.is_a?(ImplicitObj)
        name = when_cond.name[0..-2] # strip '?'
        patterns.each do |const|
          next unless const.is_a?(Const)
          type = const.namespace.as(EnumType)
          next unless const.name.underscore == name && type.question_methods.includes?(when_cond.name)
          yield const
        end
      end
    when NilLiteral
      yield nil if patterns.includes?(nil)
    when BoolLiteral
      value = when_cond.value
      yield value if patterns.includes?(value)
    when Underscore
      patterns.each { |pattern| yield pattern }
    else
      # nothing
    end
  end

  def check_exhaustiveness_step_type(patterns, type)
    case type
    when EnumType
      patterns.each do |const|
        yield const if const.is_a?(Const) && const.namespace == type
      end
    when program.bool
      yield true if patterns.includes?(true)
      yield false if patterns.includes?(false)
    when program.nil_type
      yield nil if patterns.includes?(nil)
    else
      patterns.each do |case_type|
        yield case_type if case_type.is_a?(Type) && case_type.implements?(type)
      end
    end
  end
end
