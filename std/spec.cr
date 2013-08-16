$spec_context = [] of String
$spec_results = [] of String
$spec_count = 0
$spec_failures = 0
$spec_manual_results = false

module Spec
  class RootContext
    def self.instance
      $spec_instance
    end

    def initialize
      @results = [] of Result
    end

    def success(description)
      print '.'
      @results << Result.new(:success, description)
    end

    def fail(description, ex)
      print 'F'
      @results << Result.new(:fail, description, ex)
    end

    def error(description, ex)
      print 'E'
      @results << Result.new(:error, description, ex)
    end

    def print_results
      counts = {fail: 0, success: 0, error: 0}
      puts
      @results.each do |result|
        if result.kind != :success
          if ex = result.exception
            puts "In \"#{result.description}\": #{ex.message}"
          end
        end
        counts[result.kind] += 1
      end
      puts "#{@results.length} examples, #{counts[:fail]} failures, #{counts[:error]} errors"
    end
  end

  class Context
    def initialize(description, parent)
      @description = description
      @parent = parent
    end

    def describe(description)
      describe = Spec::Context.new(description, self)
      describe.yield
    end

    def it(description)
      begin
        Assertions.yield
        @parent.success(description)
      rescue ex : AssertionFailed
        @parent.fail(description, ex)
      rescue ex
        @parent.error(description, ex)
      end
    end

    def assert
      begin
        Assertions.yield
        @parent.success("assert")
      rescue ex : AssertionFailed
        @parent.fail("assert", ex)
      rescue ex
        @parent.error("assert", ex)
      end
    end

    def success(description)
      @parent.success("#{@description} - #{description}")
    end

    def fail(description, ex)
      @parent.fail("#{@description} - #{description}", ex)
    end

    def error(description, ex)
      @parent.error("#{@description} - #{description}", ex)
    end
  end

  class Result
    getter :kind
    getter :description
    getter :exception

    def initialize(kind, description, exception = nil)
      @kind = kind
      @description = description
      @exception = exception
    end
  end

  class Assertions
    def self.eq(value)
      EqualExpectation.new value
    end

    def self.be_true
      eq true
    end

    def self.be_false
      eq false
    end

    def self.be_nil
      eq nil
    end

    def self.fail(msg)
      raise Spec::AssertionFailed.new(msg)
    end
  end

  class EqualExpectation(T)
    def initialize(value : T)
      @value = value
    end

    def match(value)
      @target = value
      value == @value
    end

    def failure_message
      "expected #{@value.inspect} but got #{@target.inspect}"
    end

    def negative_failure_message
      "didn't expect #{@value.inspect} but got #{@target.inspect}"
    end
  end

  class AssertionFailed < Exception
  end
end

$spec_instance = Spec::RootContext.new

def describe(description)
  describe = Spec::Context.new(description, Spec::RootContext.instance)
  describe.yield
end

class Object
  def should(expectation)
    unless expectation.match self
      Spec::Assertions.fail(expectation.failure_message)
    end
  end

  def should_not(expectation)
    if expectation.match self
      Spec::Assertions.fail(expectation.negative_failure_message)
    end
  end
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.__crystal_main(argc, argv)
  $spec_instance.print_results
  0
rescue
  puts "Uncaught exception"
  1
end
