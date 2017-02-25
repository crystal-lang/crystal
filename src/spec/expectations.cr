module Spec
  # :nodoc:
  struct EqualExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value == @expected_value
    end

    def failure_message(actual_value)
      expected = @expected_value.inspect
      got = actual_value.inspect
      if expected == got
        expected += " : #{@expected_value.class}"
        got += " : #{actual_value.class}"
      end
      "Expected: #{expected}\n     got: #{got}"
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

  module Expectations
    def eq(value)
      Spec::EqualExpectation.new value
    end

    def be(value)
      Spec::BeExpectation.new value
    end

    def be_true
      eq true
    end

    def be_false
      eq false
    end

    def be_truthy
      Spec::BeTruthyExpectation.new
    end

    def be_falsey
      Spec::BeFalseyExpectation.new
    end

    def be_nil
      eq nil
    end

    def be_close(expected, delta)
      Spec::CloseExpectation.new(expected, delta)
    end

    def be
      Spec::Be
    end

    def match(value)
      Spec::MatchExpectation.new(value)
    end

    # Passes if actual includes *expected*. Works on collections and `String`.
    def contain(expected)
      Spec::ContainExpectation.new(expected)
    end

    macro be_a(type)
      Spec::BeAExpectation({{type}}).new
    end

    macro expect_raises
      expect_raises(Exception, nil) do
        {{yield}}
      end
    end

    macro expect_raises(klass)
      expect_raises({{klass}}, nil) do
        {{yield}}
      end
    end

    macro expect_raises(klass, message, file = __FILE__, line = __LINE__)
      %failed = false
      begin
        {{yield}}
        %failed = true
        fail "Expected {{klass.id}} but nothing was raised", {{file}}, {{line}}
      rescue %ex : {{klass.id}}
        # We usually bubble Spec::AssertaionFailed, unless this is the expected exception
        if %ex.class == Spec::AssertionFailed && {{klass}} != Spec::AssertionFailed
          raise %ex
        end

        %msg = {{message}}
        %ex_to_s = %ex.to_s
        case %msg
        when Regex
          unless (%ex_to_s =~ %msg)
            backtrace = %ex.backtrace.map { |f| "  # #{f}" }.join "\n"
            fail "Expected {{klass.id}} with message matching #{ %msg.inspect }, got #<#{ %ex.class }: #{ %ex_to_s }> with backtrace:\n#{backtrace}", {{file}}, {{line}}
          end
        when String
          unless %ex_to_s.includes?(%msg)
            backtrace = %ex.backtrace.map { |f| "  # #{f}" }.join "\n"
            fail "Expected {{klass.id}} with #{ %msg.inspect }, got #<#{ %ex.class }: #{ %ex_to_s }> with backtrace:\n#{backtrace}", {{file}}, {{line}}
          end
        end

        %ex
      rescue %ex
        if %failed
          raise %ex
        else
          %ex_to_s = %ex.to_s
          backtrace = %ex.backtrace.map { |f| "  # #{f}" }.join "\n"
          fail "Expected {{klass.id}}, got #<#{ %ex.class }: #{ %ex_to_s }> with backtrace:\n#{backtrace}", {{file}}, {{line}}
        end
      end
    end
  end

  module ObjectExtensions
    def should(expectation, file = __FILE__, line = __LINE__)
      unless expectation.match self
        fail(expectation.failure_message(self), file, line)
      end
    end

    def should_not(expectation, file = __FILE__, line = __LINE__)
      if expectation.match self
        fail(expectation.negative_failure_message(self), file, line)
      end
    end
  end
end

include Spec::Expectations

class Object
  include Spec::ObjectExtensions
end
