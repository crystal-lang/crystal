module Spec
  # Expectation to be passed to `Object#should` and `Object#should_not`.
  #
  # An example custom expectation that checks that some value is always 42:
  #
  # ```
  # require "spec"
  #
  # struct Be42Expectation
  #   include Spec::Expectation
  #
  #   def match(value) : Bool
  #     value == 42
  #   end
  #
  #   def failure_message(value) : String
  #     "Expected #{value} to be 42"
  #   end
  #
  #   def negative_failure_message(value) : String
  #     "Expected #{value} not to be 42"
  #   end
  # end
  #
  # def be_42
  #   Be42Expectation.new
  # end
  # ```
  module Expectation
    # Matches this expectation against the given `value`, which is the
    # value that `should` or `should_not` is invoked on.
    # Returns `true` if this expectation matches the `value`, `false`
    # otherwise.
    abstract def match(value) : Bool

    # Returns a failure message for the `should` case against this
    # expectation.
    abstract def failure_message(actual_value) : String

    # Returns a failure message for the `should_not` case against this
    # expectation.
    abstract def negative_failure_message(actual_value) : String

    # Casts a value to possibly some other, narrower type, for the result
    # of a `should` invocation.
    #
    # By default this method returns `value` but some matchers, particularly
    # `be_nil` and `be_a(T)`, will return a non-nil and `T` instance,
    # respectively.
    def cast_should(value)
      value
    end

    # Casts a value to possibly some other, narrower type, for the result
    # of a `should_not` invocation.
    #
    # By default this method returns `value` but some matchers, particularly
    # `be_nil` and `be_a(T)`, will return a nil and non-`T` instance,
    # respectively.
    def cast_should_not(value)
      value
    end
  end

  # :nodoc:
  struct EqualExpectation(T)
    include Expectation

    def initialize(@expected_value : T)
    end

    def match(actual_value) : Bool
      expected_value = @expected_value

      # For the case of comparing strings we want to make sure that two strings
      # are equal if their content is equal, but also their bytesize and size
      # should be equal. Otherwise, an incorrect bytesize or size was used
      # when creating them.
      if actual_value.is_a?(String) && expected_value.is_a?(String)
        actual_value == expected_value &&
          actual_value.bytesize == expected_value.bytesize &&
          actual_value.size == expected_value.size
      else
        actual_value == @expected_value
      end
    end

    def failure_message(actual_value) : String
      expected_value = @expected_value

      # Check for the case of string equality when the content match
      # but not the bytesize or size.
      if actual_value.is_a?(String) &&
         expected_value.is_a?(String) &&
         actual_value == expected_value
        if actual_value.bytesize != expected_value.bytesize
          return <<-MSG
            Expected bytesize: #{expected_value.bytesize}
                 got bytesize: #{actual_value.bytesize}
            MSG
        end

        return <<-MSG
          Expected size: #{expected_value.size}
               got size: #{actual_value.size}
          MSG
      else
        expected = expected_value.inspect
        got = actual_value.inspect
        if expected == got
          expected += " : #{@expected_value.class}"
          got += " : #{actual_value.class}"
        end
        "Expected: #{expected}\n     got: #{got}"
      end
    end

    def negative_failure_message(actual_value) : String
      "Expected: actual_value != #{@expected_value.inspect}\n     got: #{actual_value.inspect}"
    end
  end

  # :nodoc:
  struct BeExpectation(T)
    include Expectation

    def initialize(@expected_value : T)
    end

    def match(actual_value) : Bool
      actual_value.same? @expected_value
    end

    def failure_message(actual_value) : String
      "Expected: #{@expected_value.inspect} (object_id: #{@expected_value.object_id})\n     got: #{actual_value.inspect} (object_id: #{actual_value.object_id})"
    end

    def negative_failure_message(actual_value) : String
      "Expected: value.same? #{@expected_value.inspect} (object_id: #{@expected_value.object_id})\n     got: #{actual_value.inspect} (object_id: #{actual_value.object_id})"
    end
  end

  # :nodoc:
  struct BeTruthyExpectation
    include Expectation

    def match(actual_value) : Bool
      !!actual_value
    end

    def failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} to be truthy"
    end

    def negative_failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} not to be truthy"
    end
  end

  # :nodoc:
  struct BeFalseyExpectation
    include Expectation

    def match(actual_value) : Bool
      !actual_value
    end

    def failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} to be falsey"
    end

    def negative_failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} not to be falsey"
    end
  end

  # :nodoc:
  struct BeNilExpectation
    include Expectation

    def match(actual_value) : Bool
      actual_value.nil?
    end

    def failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} to be nil"
    end

    def negative_failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} not to be nil"
    end

    def cast_should(value)
      value.nil? ? value : (raise "expected #{value} to be nil")
    end

    def cast_should_not(value)
      value.nil? ? (raise "expected #{value} to not be nil") : value
    end
  end

  # :nodoc:
  struct CloseExpectation(T, D)
    include Expectation

    def initialize(@expected_value : T, @delta : D)
    end

    def match(actual_value) : Bool
      (actual_value - @expected_value).abs <= @delta
    end

    def failure_message(actual_value) : String
      "Expected #{actual_value.inspect} to be within #{@delta} of #{@expected_value}"
    end

    def negative_failure_message(actual_value) : String
      "Expected #{actual_value.inspect} not to be within #{@delta} of #{@expected_value}"
    end
  end

  # :nodoc:
  struct BeAExpectation(T)
    include Expectation

    def match(actual_value) : Bool
      actual_value.is_a?(T)
    end

    def failure_message(actual_value) : String
      "Expected #{actual_value.inspect} (#{actual_value.class}) to be a #{T}"
    end

    def negative_failure_message(actual_value) : String
      "Expected #{actual_value.inspect} (#{actual_value.class}) not to be a #{T}"
    end

    def cast_should(value)
      value.is_a?(T) ? value : (raise "expected #{value} to be a #{T}")
    end

    def cast_should_not(value)
      value.is_a?(T) ? (raise "expected #{value} to not be a #{T}") : value
    end
  end

  # :nodoc:
  struct Be(T)
    include Expectation

    def self.<(other)
      Be.new(other, :"<")
    end

    def self.<=(other)
      Be.new(other, :"<=")
    end

    def self.>(other)
      Be.new(other, :">")
    end

    def self.>=(other)
      Be.new(other, :">=")
    end

    def initialize(@expected_value : T, @op : Symbol)
    end

    def match(actual_value) : Bool
      case @op
      when :"<"
        actual_value < @expected_value
      when :"<="
        actual_value <= @expected_value
      when :">"
        actual_value > @expected_value
      when :">="
        actual_value >= @expected_value
      else
        false
      end
    end

    def failure_message(actual_value) : String
      "Expected #{actual_value.inspect} to be #{@op} #{@expected_value}"
    end

    def negative_failure_message(actual_value) : String
      "Expected #{actual_value.inspect} not to be #{@op} #{@expected_value}"
    end
  end

  # :nodoc:
  struct MatchExpectation(T)
    include Expectation

    def initialize(@expected_value : T)
    end

    def match(actual_value) : Bool
      !!(actual_value =~ @expected_value)
    end

    def failure_message(actual_value) : String
      "Expected: #{actual_value.inspect}\nto match: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value) : String
      "Expected: value #{actual_value.inspect}\n to not match: #{@expected_value.inspect}"
    end
  end

  # :nodoc:
  struct ContainExpectation(T)
    include Expectation

    def initialize(@expected_value : T)
    end

    def match(actual_value) : Bool
      actual_value.includes?(@expected_value)
    end

    def failure_message(actual_value) : String
      "Expected:   #{actual_value.inspect}\nto include: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value) : String
      "Expected: value #{actual_value.inspect}\nto not include: #{@expected_value.inspect}"
    end
  end

  # :nodoc:
  struct StartWithExpectation(T)
    include Expectation

    def initialize(@expected_value : T)
    end

    def match(actual_value) : Bool
      actual_value.starts_with?(@expected_value)
    end

    def failure_message(actual_value) : String
      "Expected:   #{actual_value.inspect}\nto start with: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value) : String
      "Expected: value #{actual_value.inspect}\nnot to start with: #{@expected_value.inspect}"
    end
  end

  # :nodoc:
  struct EndWithExpectation(T)
    include Expectation

    def initialize(@expected_value : T)
    end

    def match(actual_value) : Bool
      actual_value.ends_with?(@expected_value)
    end

    def failure_message(actual_value) : String
      "Expected:   #{actual_value.inspect}\nto end with: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value) : String
      "Expected: value #{actual_value.inspect}\nnot to end with: #{@expected_value.inspect}"
    end
  end

  # :nodoc:
  struct BeEmptyExpectation
    include Expectation

    def match(actual_value) : Bool
      actual_value.empty?
    end

    def failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} to be empty"
    end

    def negative_failure_message(actual_value) : String
      "Expected: #{actual_value.inspect} not to be empty"
    end
  end

  # This module defines a number of methods to create expectations, which are
  # automatically included into the top level namespace.
  #
  # Expectations are used by `Spec::ObjectExtensions#should` and `Spec::ObjectExtensions#should_not`.
  module Expectations
    # Creates an `Expectation` that passes if actual equals *value* (`==`).
    def eq(value) : Expectation
      Spec::EqualExpectation.new value
    end

    # Creates an `Expectation` that passes if actual and *value* are identical (`.same?`).
    def be(value) : Expectation
      Spec::BeExpectation.new value
    end

    # Creates an `Expectation` that passes if actual is true (`== true`).
    def be_true : Expectation
      eq true
    end

    # Creates an `Expectation` that passes if actual is false (`== false`).
    def be_false : Expectation
      eq false
    end

    # Creates an `Expectation` that passes if actual is truthy (neither `nil` nor `false`).
    def be_truthy : Expectation
      Spec::BeTruthyExpectation.new
    end

    # Creates an `Expectation` that passes if actual is falsy (`nil` or `false`).
    def be_falsey : Expectation
      Spec::BeFalseyExpectation.new
    end

    # Creates an `Expectation` that passes if actual is nil (`== nil`).
    #
    # When using it for a `should_not` expectation, the result of the
    # `should_not` call will be the receiver without the Nil type.
    #
    # For example:
    #
    # ```crystal
    # value = "foo".index('o')
    # typeof(value) # => Int32 | Nil
    #
    # result = value.should_not be_nil
    # typeof(result) # => Int32
    # ```
    def be_nil : Expectation
      Spec::BeNilExpectation.new
    end

    # Creates an `Expectation` that passes if actual is within *delta* of *expected*.
    def be_close(expected, delta) : Expectation
      Spec::CloseExpectation.new(expected, delta)
    end

    # Returns a factory to create a comparison `Expectation` that:
    #
    # * passes if actual is lesser than *value*: `be < value`
    # * passes if actual is lesser than or equal *value*: `be <= value`
    # * passes if actual is greater than *value*: `be > value`
    # * passes if actual is greater than or equal *value*: `be >= value`
    def be
      Spec::Be
    end

    # Creates an `Expectation` that passes if actual matches *value* (`=~`).
    def match(value) : Expectation
      Spec::MatchExpectation.new(value)
    end

    # Creates an `Expectation` that passes if actual includes *expected* (`.includes?`).
    # Works on collections and `String`.
    def contain(expected) : Expectation
      Spec::ContainExpectation.new(expected)
    end

    # Creates an `Expectation` that passes if actual starts with *expected* (`.starts_with?`).
    # Works on `String`.
    def start_with(expected) : Expectation
      Spec::StartWithExpectation.new(expected)
    end

    # Creates an `Expectation` that passes if actual ends with *expected* (`.ends_with?`).
    # Works on `String`.
    def end_with(expected) : Expectation
      Spec::EndWithExpectation.new(expected)
    end

    # Creates an `Expectation` that passes if actual is empty (`.empty?`).
    def be_empty : Expectation
      Spec::BeEmptyExpectation.new
    end

    # Creates an `Expectation` that passes if actual is of type *type* (`is_a?`).
    #
    # When using it for a `should` expectation, the result of the
    # `should` call will be the receiver as the given `type`.
    #
    # For example:
    #
    # ```crystal
    # value = "foo".index('o')
    # typeof(value) # => Int32 | Nil
    #
    # result = value.should be_a(Int32)
    # typeof(result) # => Int32
    # ```
    #
    # When using it for a `should_not` expectation, the result of the
    # `should_not` call will be the receiver excluding the given `type`.
    #
    # For example:
    #
    # ```crystal
    # value = "foo".index('o')
    # typeof(value) # => Int32 | Nil
    #
    # result = value.should_not be_a(Nil)
    # typeof(result) # => Int32
    # ```
    macro be_a(type)
      Spec::BeAExpectation({{type}}).new
    end

    # Runs the block and passes if it raises an exception of type *klass* and the error message matches.
    #
    # If *message* is a string, it matches if the exception's error message contains that string.
    # If *message* is a regular expression, it is used to match the error message.
    #
    # It returns the rescued exception.
    def expect_raises(klass : T.class, message = nil, file = __FILE__, line = __LINE__) forall T
      yield
    rescue ex : T
      # We usually bubble Spec::AssertaionFailed, unless this is the expected exception
      if ex.is_a?(Spec::AssertionFailed) && klass != Spec::AssertionFailed
        raise ex
      end

      # `NestingSpecError` is treated as the same above.
      if ex.is_a?(Spec::NestingSpecError) && klass != Spec::NestingSpecError
        raise ex
      end

      ex_to_s = ex.to_s
      case message
      when Regex
        unless (ex_to_s =~ message)
          backtrace = ex.backtrace.join('\n') { |f| "  # #{f}" }
          fail "Expected #{klass} with message matching #{message.inspect}, " \
               "got #<#{ex.class}: #{ex_to_s}> with backtrace:\n#{backtrace}", file, line
        end
      when String
        unless ex_to_s.includes?(message)
          backtrace = ex.backtrace.join('\n') { |f| "  # #{f}" }
          fail "Expected #{klass} with #{message.inspect}, got #<#{ex.class}: " \
               "#{ex_to_s}> with backtrace:\n#{backtrace}", file, line
        end
      end

      ex
    rescue ex
      backtrace = ex.backtrace.join('\n') { |f| "  # #{f}" }
      fail "Expected #{klass}, got #<#{ex.class}: #{ex.to_s}> with backtrace:\n" \
           "#{backtrace}", file, line
    else
      fail "Expected #{klass} but nothing was raised", file, line
    end
  end

  module ObjectExtensions
    # Validates an expectation and fails the example if it does not match.
    #
    # See `Spec::Expecations` for available expectations.
    def should(expectation : Expectation, file = __FILE__, line = __LINE__)
      unless expectation.match self
        fail(expectation.failure_message(self), file, line)
      end
      expectation.cast_should(self)
    end

    # Validates an expectation and fails the example if it matches.
    #
    # See `Spec::Expecations` for available expectations.
    def should_not(expectation : Expectation, file = __FILE__, line = __LINE__)
      if expectation.match self
        fail(expectation.negative_failure_message(self), file, line)
      end
      expectation.cast_should_not(self)
    end
  end
end

include Spec::Expectations

class Object
  include Spec::ObjectExtensions
end
