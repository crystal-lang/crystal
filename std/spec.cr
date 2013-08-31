module Spec
  class Result
    getter :kind
    getter :description
    getter :exception

    def initialize(@kind, @description, @exception = nil)
    end
  end

  abstract class Context
  end

  class RootContext < Context
    def initialize
      @results = [] of Result
      @has_failures = false
    end

    def self.report(kind, description, ex = nil)
      @@contexts_stack.last.report(kind, description, ex)
    end

    def report(kind, description, ex = nil)
      case kind
      when :success
        print '.'
      when :fail
        print 'F'
        @has_failures = true
      when :error
        print 'E'
        @has_failures = true
      end
      @results << Result.new(kind, description, ex)
    end

    def self.print_results
      @@instance.print_results
    end

    def print_results
      counts = {fail: 0, success: 0, error: 0}
      puts

      if @has_failures
        puts
        puts "Failures:"
        failure_counter = 1
        @results.each do |result|
          if result.kind != :success
            if ex = result.exception
              puts
              puts "  #{failure_counter}) #{result.description}"
              puts
              if msg = ex.message
                msg.split("\n").each do |line|
                  print "       "
                  puts line
                end
              end
            end
            failure_counter += 1
          end
          counts[result.kind] += 1
        end
        puts
      end
      puts "#{@results.length} examples, #{counts[:fail]} failures, #{counts[:error]} errors"
    end

    @@instance = RootContext.new
    @@contexts_stack = [@@instance] of Context

    def self.describe(description)
      describe = Spec::NestedContext.new(description, @@contexts_stack.last)
      @@contexts_stack.push describe
      yield describe
      @@contexts_stack.pop
    end
  end

  class NestedContext < Context
    def initialize(@description, @parent)
    end

    def report(kind, description, ex = nil)
      @parent.report(kind, "#{@description} #{description}", ex)
    end
  end

  class EqualExpectation(T)
    def initialize(@value : T)
    end

    def match(value)
      @target = value
      value == @value
    end

    def failure_message
      "expected: #{@value.inspect}\n     got: #{@target.inspect}"
    end

    def negative_failure_message
      "expected: value != #{@value.inspect}\n     got: #{@target.inspect}"
    end
  end

  class CloseExpectation
    def initialize(@expected, @delta)
    end

    def match(value)
      @target = value
      (@target - @expected).abs <= @delta
    end

    def failure_message
      "expected #{@target} to be within #{@delta} of #{@expected}"
    end

    def negative_failure_message
      "expected #{@target} not to be within #{@delta} of #{@expected}"
    end
  end

  class AssertionFailed < Exception
  end
end

def describe(description)
  Spec::RootContext.describe(description) do |context|
    yield
  end
end

def it(description)
  begin
    yield
    Spec::RootContext.report(:success, description)
  rescue ex : Spec::AssertionFailed
    Spec::RootContext.report(:fail, description, ex)
  rescue ex
    Spec::RootContext.report(:error, description, ex)
  end
end

def assert
  it("assert") { yield }
end

def eq(value)
  Spec::EqualExpectation.new value
end

def be_true
  eq true
end

def be_false
  eq false
end

def be_nil
  eq nil
end

def be_close(expected, delta)
  Spec::CloseExpectation.new(expected, delta)
end

def fail(msg)
  raise Spec::AssertionFailed.new(msg)
end

class Object
  def should(expectation)
    unless expectation.match self
      fail(expectation.failure_message)
    end
  end

  def should_not(expectation)
    if expectation.match self
      fail(expectation.negative_failure_message)
    end
  end
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.__crystal_main(argc, argv)
  Spec::RootContext.print_results
  0
rescue ex
  puts ex
  1
end
