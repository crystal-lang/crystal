module Spec
  # :nodoc:
  struct EqualExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
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

    def failure_message(actual_value)
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

        <<-MSG
        Expected size: #{expected_value.size}
              got size: #{actual_value.size}
        MSG
      else
        expected = expected_value.pretty_inspect
        got = actual_value.pretty_inspect
        if expected == got
          expected += " : #{@expected_value.class}"
          got += " : #{actual_value.class}"
        end
        "Expected: #{expected}\n     got: #{got}"
      end
    end

    def negative_failure_message(actual_value)
      "Expected: actual_value != #{@expected_value.pretty_inspect}\n     got: #{actual_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct BeExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value.same? @expected_value
    end

    def failure_message(actual_value)
      "Expected: #{@expected_value.pretty_inspect} (object_id: #{@expected_value.object_id})\n     got: #{actual_value.pretty_inspect} (object_id: #{actual_value.object_id})"
    end

    def negative_failure_message(actual_value)
      "Expected: value.same? #{@expected_value.pretty_inspect} (object_id: #{@expected_value.object_id})\n     got: #{actual_value.pretty_inspect} (object_id: #{actual_value.object_id})"
    end
  end

  # :nodoc:
  struct BeTruthyExpectation
    def match(actual_value)
      !!actual_value
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} to be truthy"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} not to be truthy"
    end
  end

  # :nodoc:
  struct BeFalseyExpectation
    def match(actual_value)
      !actual_value
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} to be falsey"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} not to be falsey"
    end
  end

  # :nodoc:
  struct BeNilExpectation
    def match(actual_value)
      actual_value.nil?
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} to be nil"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} not to be nil"
    end
  end

  # :nodoc:
  struct CloseExpectation(T, D)
    def initialize(@expected_value : T, @delta : D)
    end

    def match(actual_value)
      (actual_value - @expected_value).abs <= @delta
    end

    def failure_message(actual_value)
      "Expected #{actual_value.pretty_inspect} to be within #{@delta} of #{@expected_value.pretty_inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected #{actual_value.pretty_inspect} not to be within #{@delta} of #{@expected_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct BeAExpectation(T)
    def match(actual_value)
      actual_value.is_a?(T)
    end

    def failure_message(actual_value)
      "Expected #{actual_value.pretty_inspect} (#{actual_value.class}) to be a #{T}"
    end

    def negative_failure_message(actual_value)
      "Expected #{actual_value.pretty_inspect} (#{actual_value.class}) not to be a #{T}"
    end
  end

  # :nodoc:
  struct Be(T)
    enum Relation
      LessThan
      LessOrEqual
      GreaterThan
      GreaterOrEqual
    end

    def self.<(other)
      Be.new(other, :less_than)
    end

    def self.<=(other)
      Be.new(other, :less_or_equal)
    end

    def self.>(other)
      Be.new(other, :greater_than)
    end

    def self.>=(other)
      Be.new(other, :greater_or_equal)
    end

    def initialize(@expected_value : T, @op : Relation)
    end

    def match(actual_value)
      case @op
      in .less_than?
        actual_value < @expected_value
      in .less_or_equal?
        actual_value <= @expected_value
      in .greater_than?
        actual_value > @expected_value
      in .greater_or_equal?
        actual_value >= @expected_value
      end
    end

    def failure_message(actual_value)
      "Expected #{actual_value.pretty_inspect} to be #{@op} #{@expected_value.pretty_inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected #{actual_value.pretty_inspect} not to be #{@op} #{@expected_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct MatchExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value =~ @expected_value
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect}\nto match: #{@expected_value.pretty_inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.pretty_inspect}\n to not match: #{@expected_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct ContainExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value.includes?(@expected_value)
    end

    def failure_message(actual_value)
      "Expected:   #{actual_value.pretty_inspect}\nto include: #{@expected_value.pretty_inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.pretty_inspect}\nto not include: #{@expected_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct StartWithExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value.starts_with?(@expected_value)
    end

    def failure_message(actual_value)
      "Expected:   #{actual_value.pretty_inspect}\nto start with: #{@expected_value.pretty_inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.pretty_inspect}\nnot to start with: #{@expected_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct EndWithExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value.ends_with?(@expected_value)
    end

    def failure_message(actual_value)
      "Expected:   #{actual_value.pretty_inspect}\nto end with: #{@expected_value.pretty_inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.pretty_inspect}\nnot to end with: #{@expected_value.pretty_inspect}"
    end
  end

  # :nodoc:
  struct BeEmptyExpectation
    def match(actual_value)
      actual_value.empty?
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} to be empty"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.pretty_inspect} not to be empty"
    end
  end

  # This module defines a number of methods to create expectations, which are
  # automatically included into the top level namespace.
  #
  # Expectations are used by `Spec::ObjectExtensions#should` and `Spec::ObjectExtensions#should_not`.
  module Expectations
    # Creates an `Expectation` that passes if actual equals *value* (`==`).
    def eq(value)
      Spec::EqualExpectation.new value
    end

    # Creates an `Expectation` that passes if actual and *value* are identical (`.same?`).
    def be(value)
      Spec::BeExpectation.new value
    end

    # Creates an `Expectation` that passes if actual is true (`== true`).
    def be_true
      eq true
    end

    # Creates an `Expectation` that passes if actual is false (`== false`).
    def be_false
      eq false
    end

    # Creates an `Expectation` that passes if actual is truthy (neither `nil` nor `false`).
    def be_truthy
      Spec::BeTruthyExpectation.new
    end

    # Creates an `Expectation` that passes if actual is falsy (`nil` or `false`).
    def be_falsey
      Spec::BeFalseyExpectation.new
    end

    # Creates an `Expectation` that passes if actual is nil (`== nil`).
    def be_nil
      Spec::BeNilExpectation.new
    end

    # Creates an `Expectation` that passes if actual is within *delta* of *expected*.
    def be_close(expected, delta)
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
    def match(value)
      Spec::MatchExpectation.new(value)
    end

    # Creates an `Expectation` that passes if actual includes *expected* (`.includes?`).
    # Works on collections and `String`.
    def contain(expected)
      Spec::ContainExpectation.new(expected)
    end

    # Creates an `Expectation` that passes if actual starts with *expected* (`.starts_with?`).
    # Works on `String`.
    def start_with(expected)
      Spec::StartWithExpectation.new(expected)
    end

    # Creates an `Expectation` that passes if actual ends with *expected* (`.ends_with?`).
    # Works on `String`.
    def end_with(expected)
      Spec::EndWithExpectation.new(expected)
    end

    # Creates an `Expectation` that passes if actual is empty (`.empty?`).
    def be_empty
      Spec::BeEmptyExpectation.new
    end

    # Creates an `Expectation` that passes if actual is of type *type* (`is_a?`).
    macro be_a(type)
      ::Spec::BeAExpectation({{type}}).new
    end

    # Runs the block and passes if it raises an exception of type *klass* and the error message matches.
    #
    # If *message* is a string, it matches if the exception's error message contains that string.
    # If *message* is a regular expression, it is used to match the error message.
    #
    # It returns the rescued exception.
    {% if flag?(:wasm32) %}
      def expect_raises(klass : T.class, message : String | Regex | Nil = nil, file = __FILE__, line = __LINE__, &) forall T
        # TODO: Enable "expect_raises" for wasm32 after exceptions are working.
      end
    {% else %}
      def expect_raises(klass : T.class, message : String | Regex | Nil = nil, file = __FILE__, line = __LINE__, &) forall T
        yield
      rescue ex : T
        # We usually bubble Spec::AssertionFailed, unless this is the expected exception
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
            fail "Expected #{klass} with message matching #{message.pretty_inspect}, " \
                 "got #<#{ex.class}: #{ex_to_s}> with backtrace:\n#{backtrace}", file, line
          end
        when String
          unless ex_to_s.includes?(message)
            backtrace = ex.backtrace.join('\n') { |f| "  # #{f}" }
            fail "Expected #{klass} with #{message.pretty_inspect}, got #<#{ex.class}: " \
                 "#{ex_to_s}> with backtrace:\n#{backtrace}", file, line
          end
        when Nil
          # No need to check the message
        end

        ex
      rescue ex
        backtrace = ex.backtrace.join('\n') { |f| "  # #{f}" }
        fail "Expected #{klass}, got #<#{ex.class}: #{ex}> with backtrace:\n" \
             "#{backtrace}", file, line
      else
        fail "Expected #{klass} but nothing was raised", file, line
      end
    {% end %}
  end

  module ObjectExtensions
    # Validates an expectation and fails the example if it does not match.
    #
    # This overload returns a value whose type is restricted to the expected type. For example:
    #
    # ```
    # x = 1 || 'a'
    # typeof(x) # => Int32 | Char
    # x = x.should be_a(Int32)
    # typeof(x) # => Int32
    # ```
    #
    # See `Spec::Expectations` for available expectations.
    def should(expectation : BeAExpectation(T), failure_message : String? = nil, *, file = __FILE__, line = __LINE__) : T forall T
      if expectation.match self
        self.is_a?(T) ? self : (raise "Bug: expected #{self} to be a #{T}")
      else
        failure_message ||= expectation.failure_message(self)
        fail(failure_message, file, line)
      end
    end

    # Validates an expectation and fails the example if it does not match.
    #
    # See `Spec::Expectations` for available expectations.
    def should(expectation, failure_message : String? = nil, *, file = __FILE__, line = __LINE__)
      unless expectation.match self
        failure_message ||= expectation.failure_message(self)
        fail(failure_message, file, line)
      end
    end

    # Validates an expectation and fails the example if it matches.
    #
    # This overload returns a value whose type is restricted to exclude the given
    # type in `should_not be_a`. For example:
    #
    # ```
    # x = 1 || 'a'
    # typeof(x) # => Int32 | Char
    # x = x.should_not be_a(Char)
    # typeof(x) # => Int32
    # ```
    #
    # See `Spec::Expectations` for available expectations.
    def should_not(expectation : BeAExpectation(T), failure_message : String? = nil, *, file = __FILE__, line = __LINE__) forall T
      if expectation.match self
        failure_message ||= expectation.negative_failure_message(self)
        fail(failure_message, file, line)
      else
        self.is_a?(T) ? (raise "Bug: expected #{self} not to be a #{T}") : self
      end
    end

    # Validates an expectation and fails the example if it matches.
    #
    # This overload returns a value whose type is restricted to be not `Nil`. For example:
    #
    # ```
    # x = 1 || nil
    # typeof(x) # => Int32 | Nil
    # x = x.should_not be_nil
    # typeof(x) # => Int32
    # ```
    #
    # See `Spec::Expectations` for available expectations.
    def should_not(expectation : BeNilExpectation, failure_message : String? = nil, *, file = __FILE__, line = __LINE__)
      if expectation.match self
        failure_message ||= expectation.negative_failure_message(self)
        fail(failure_message, file, line)
      else
        self.not_nil!
      end
    end

    # Validates an expectation and fails the example if it matches.
    #
    # See `Spec::Expectations` for available expectations.
    def should_not(expectation, failure_message : String? = nil, *, file = __FILE__, line = __LINE__)
      if expectation.match self
        failure_message ||= expectation.negative_failure_message(self)
        fail(failure_message, file, line)
      end
    end
  end
end

include Spec::Expectations

class Object
  include Spec::ObjectExtensions
end
