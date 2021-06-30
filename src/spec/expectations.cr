module Spec
  # A list of diff command candidates.
  DIFF_COMMANDS = [
    %w(git diff --no-index -U3),
    %w(gdiff -u),
    %w(diff -u),
  ]

  # A diff command path and options to use in diff computation.
  class_property diff_command : Array(String)? do
    DIFF_COMMANDS.each.compact_map { |cmd| check_diff_command(cmd) }.first?
  end

  # A flag whether it uses diff on generating a expectation message.
  class_property? use_diff : Bool { diff_command != nil }

  # Checks the given `diff` command works.
  # It takes an array of strings as `diff` command and options,
  # and it returns a new array with resolved path and options if it works,
  # otherwise it returns `nil`.
  private def self.check_diff_command(cmd)
    name = Process.find_executable(cmd[0])
    return unless name
    opts = cmd[1..]

    begin
      tmp_file = File.tempfile { |f| f.puts "check_diff" }

      # Try to invoke `diff` against a temporary file.
      # When the `diff` exists with success status and its output is empty,
      # we assume the `diff` command works.
      output = String.build do |io|
        status = Process.run(name, opts + [tmp_file.path, tmp_file.path], output: io)
        return unless status.success?
      end
      return unless output.empty?
    ensure
      # Clean up temporary files!
      tmp_file.try &.delete
    end

    [name] + opts
  end

  # Compute the difference between two values *expected_value* and *actual_value*
  # by using `diff` command.
  def self.diff_values(expected_value, actual_value)
    expected = expected_value.pretty_inspect
    actual = actual_value.pretty_inspect

    result = diff expected, actual

    # When the diff output is nothing even though the two values do not equal,
    # it returns a fallback message so far.
    if result && result.empty?
      klass = expected_value.class
      return <<-MSG
        No visible difference in the `#{klass}#pretty_inspect` output.
        You should look at the implementation of `#==` on #{klass} or its members.
        MSG
    end

    result
  end

  # Compute the difference between two strings *expected* and *actual*
  # by using `diff` command.
  def self.diff(expected, actual)
    return unless Spec.use_diff?

    # If the diff command is available and outputs contain a newline,
    # then it computes diff of them.
    diff_command = Spec.diff_command
    return unless diff_command && (expected.includes?('\n') || actual.includes?('\n'))
    diff_command_name = diff_command[0]
    diff_command_opts = diff_command[1..]

    begin
      expected_file = File.tempfile("expected") { |f| f.puts expected }
      actual_file = File.tempfile("actual") { |f| f.puts actual }

      # Invoke `diff` command and fix up its output.
      output = String.build do |io|
        Process.run(diff_command_name, diff_command_opts + [expected_file.path, actual_file.path], output: io)
      end
      # Remove `--- expected` and `+++ actual` lines.
      output.chomp.gsub(/^(-{3}|\+{3}|diff --\w+|index) .+?\n/m, "")
    ensure
      # Clean up temporary files!
      expected_file.try &.delete
      actual_file.try &.delete
    end
  end

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
        msg = <<-MSG
          Expected: #{expected}
               got: #{got}
          MSG
        if diff = Spec.diff_values(expected_value, actual_value)
          msg = <<-MSG
            #{msg}

            Difference:
            #{diff}
            MSG
        end
        msg
      end
    end

    def negative_failure_message(actual_value)
      "Expected: actual_value != #{@expected_value.inspect}\n     got: #{actual_value.inspect}"
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
      "Expected: #{@expected_value.inspect} (object_id: #{@expected_value.object_id})\n     got: #{actual_value.inspect} (object_id: #{actual_value.object_id})"
    end

    def negative_failure_message(actual_value)
      "Expected: value.same? #{@expected_value.inspect} (object_id: #{@expected_value.object_id})\n     got: #{actual_value.inspect} (object_id: #{actual_value.object_id})"
    end
  end

  # :nodoc:
  struct BeTruthyExpectation
    def match(actual_value)
      !!actual_value
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.inspect} to be truthy"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.inspect} not to be truthy"
    end
  end

  # :nodoc:
  struct BeFalseyExpectation
    def match(actual_value)
      !actual_value
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.inspect} to be falsey"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.inspect} not to be falsey"
    end
  end

  # :nodoc:
  struct BeNilExpectation
    def match(actual_value)
      actual_value.nil?
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.inspect} to be nil"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.inspect} not to be nil"
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
      "Expected #{actual_value.inspect} to be within #{@delta} of #{@expected_value}"
    end

    def negative_failure_message(actual_value)
      "Expected #{actual_value.inspect} not to be within #{@delta} of #{@expected_value}"
    end
  end

  # :nodoc:
  struct BeAExpectation(T)
    def match(actual_value)
      actual_value.is_a?(T)
    end

    def failure_message(actual_value)
      "Expected #{actual_value.inspect} (#{actual_value.class}) to be a #{T}"
    end

    def negative_failure_message(actual_value)
      "Expected #{actual_value.inspect} (#{actual_value.class}) not to be a #{T}"
    end
  end

  # :nodoc:
  struct Be(T)
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

    def match(actual_value)
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

    def failure_message(actual_value)
      "Expected #{actual_value.inspect} to be #{@op} #{@expected_value}"
    end

    def negative_failure_message(actual_value)
      "Expected #{actual_value.inspect} not to be #{@op} #{@expected_value}"
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
      "Expected: #{actual_value.inspect}\nto match: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.inspect}\n to not match: #{@expected_value.inspect}"
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
      "Expected:   #{actual_value.inspect}\nto include: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.inspect}\nto not include: #{@expected_value.inspect}"
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
      "Expected:   #{actual_value.inspect}\nto start with: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.inspect}\nnot to start with: #{@expected_value.inspect}"
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
      "Expected:   #{actual_value.inspect}\nto end with: #{@expected_value.inspect}"
    end

    def negative_failure_message(actual_value)
      "Expected: value #{actual_value.inspect}\nnot to end with: #{@expected_value.inspect}"
    end
  end

  # :nodoc:
  struct BeEmptyExpectation
    def match(actual_value)
      actual_value.empty?
    end

    def failure_message(actual_value)
      "Expected: #{actual_value.inspect} to be empty"
    end

    def negative_failure_message(actual_value)
      "Expected: #{actual_value.inspect} not to be empty"
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
    def expect_raises(klass : T.class, message : String | Regex | Nil = nil, file = __FILE__, line = __LINE__) forall T
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
          fail "Expected #{klass} with message matching #{message.inspect}, " \
               "got #<#{ex.class}: #{ex_to_s}> with backtrace:\n#{backtrace}", file, line
        end
      when String
        unless ex_to_s.includes?(message)
          backtrace = ex.backtrace.join('\n') { |f| "  # #{f}" }
          fail "Expected #{klass} with #{message.inspect}, got #<#{ex.class}: " \
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
