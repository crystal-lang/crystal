module Spec
  # :nodoc:
  class EqualExpectation(T)
    def initialize(@value : T)
    end

    def match(value)
      @target = value
      value == @value
    end

    def failure_message
      expected = @value.inspect
      got = @target.inspect
      if expected == got
        expected += " : #{@value.class}"
        got += " : #{@target.class}"
      end
      "expected: #{expected}\n     got: #{got}"
    end

    def negative_failure_message
      "expected: value != #{@value.inspect}\n     got: #{@target.inspect}"
    end
  end

  # :nodoc:
  class BeExpectation(T)
    def initialize(@value : T)
    end

    def match(value)
      @target = value
      value.same? @value
    end

    def failure_message
      "expected: #{@value.inspect} (object_id: #{@value.object_id})\n     got: #{@target.inspect} (object_id: #{@target.object_id})"
    end

    def negative_failure_message
      "expected: value.same? #{@value.inspect} (object_id: #{@value.object_id})\n     got: #{@target.inspect} (object_id: #{@target.object_id})"
    end
  end

  # :nodoc:
  class BeTruthyExpectation
    def match(@value)
      !!@value
    end

    def failure_message
      "expected: #{@value.inspect} to be truthy"
    end

    def negative_failure_message
      "expected: #{@value.inspect} not to be truthy"
    end
  end

  # :nodoc:
  class BeFalseyExpectation
    def match(@value)
      !@value
    end

    def failure_message
      "expected: #{@value.inspect} to be falsey"
    end

    def negative_failure_message
      "expected: #{@value.inspect} not to be falsey"
    end
  end

  # :nodoc:
  class CloseExpectation
    def initialize(@expected, @delta)
    end

    def match(value)
      @target = value
      (value - @expected).abs <= @delta
    end

    def failure_message
      "expected #{@target.inspect} to be within #{@delta} of #{@expected}"
    end

    def negative_failure_message
      "expected #{@target.inspect} not to be within #{@delta} of #{@expected}"
    end
  end

  # :nodoc:
  class BeAExpectation(T)
    def match(value)
      @target = value
      value.is_a?(T)
    end

    def failure_message
      "expected #{@target.inspect} (#{@target.class}) to be a #{T}"
    end

    def negative_failure_message
      "expected #{@target.inspect} (#{@target.class}) not to be a #{T}"
    end
  end

  # :nodoc:
  class Be(T)
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

    def initialize(@expected : T, @op)
    end

    def match(value)
      @target = value

      case @op
      when :"<"
        value < @expected
      when :"<="
        value <= @expected
      when :">"
        value > @expected
      when :">="
        value >= @expected
      else
        false
      end
    end

    def failure_message
      "expected #{@target.inspect} to be #{@op} #{@expected}"
    end

    def negative_failure_message
      "expected #{@target.inspect} not to be #{@op} #{@expected}"
    end
  end

  # :nodoc:
  class MatchExpectation(T)
    def initialize(@value : T)
    end

    def match(value)
      @target = value
      @target =~ @value
    end

    def failure_message
      "expected: #{@target.inspect}\nto match: #{@value.inspect}"
    end

    def negative_failure_message
      "expected: value #{@target.inspect}\n to not match: #{@value.inspect}"
    end
  end

  # :nodoc:
  class ContainExpectation(T)
    def initialize(@expected : T)
    end

    def match(actual)
      @actual = actual
      actual.includes?(@expected)
    end

    def failure_message
      "expected:   #{@actual.inspect}\nto include: #{@expected.inspect}"
    end

    def negative_failure_message
      "expected: value #{@actual.inspect}\nto not include: #{@expected.inspect}"
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

    # Passes if actual includes expected. Works on collections and String.
    # @param expected - item expected to be contained in actual
    def contain(expected)
      Spec::ContainExpectation.new(expected)
    end

    macro be_a(type)
      Spec::BeAExpectation({{type}}).new
    end

    macro expect_raises
      expect_raises(Exception) do
        {{yield}}
      end
    end

    macro expect_raises(klass)
      expect_raises({{klass}}, nil) do
        {{yield}}
      end
    end

    macro expect_raises(klass, message)
      %failed = false
      begin
        {{yield}}
        %failed = true
        fail "expected {{klass.id}} but nothing was raised"
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
            fail "expected {{klass.id}} with message matching #{ %msg.inspect }, got #<#{ %ex.class }: #{ %ex_to_s }> with backtrace:\n#{backtrace}"
          end
        when String
          unless %ex_to_s.includes?(%msg)
            backtrace = %ex.backtrace.map { |f| "  # #{f}" }.join "\n"
            fail "expected {{klass.id}} with #{ %msg.inspect }, got #<#{ %ex.class }: #{ %ex_to_s }> with backtrace:\n#{backtrace}"
          end
        end
      rescue %ex
        if %failed
          raise %ex
        else
          %ex_to_s = %ex.to_s
          backtrace = %ex.backtrace.map { |f| "  # #{f}" }.join "\n"
          fail "expected {{klass.id}}, got #<#{ %ex.class }: #{ %ex_to_s }> with backtrace:\n#{backtrace}"
        end
      end
    end
  end

  module ObjectExtensions
    def should(expectation, file = __FILE__, line = __LINE__)
      unless expectation.match self
        fail(expectation.failure_message, file, line)
      end
    end

    def should_not(expectation, file = __FILE__, line = __LINE__)
      if expectation.match self
        fail(expectation.negative_failure_message, file, line)
      end
    end
  end
end

include Spec::Expectations

class Object
  include Spec::ObjectExtensions
end
