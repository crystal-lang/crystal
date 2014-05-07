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
    COLORS = {
      success: 32,
      fail: 31,
      error: 31,
      pending: 33,
    }

    LETTERS = {
      success: '.',
      fail: 'F',
      error: 'E',
      pending: '*',
    }

    def initialize
      @results = {
        success: [] of Result,
        fail: [] of Result,
        error: [] of Result,
        pending: [] of Result,
      }
    end

    def succeeded
      @results[:fail].empty? && @results[:error].empty?
    end

    def self.report(kind, description, ex = nil)
      @@contexts_stack.last.report(kind, description, ex)
    end

    def color(str, status)
      "\e[0;#{COLORS[status]}m#{str}\e[0m"
    end

    def report(kind, description, ex = nil)
      print color(LETTERS[kind], kind)
      C.fflush nil
      @results[kind] << Result.new(kind, description, ex)
    end

    def self.print_results(elapsed_time)
      @@instance.print_results(elapsed_time)
    end

    def self.succeeded
      @@instance.succeeded
    end

    def print_results(elapsed_time)
      puts

      pendings = @results[:pending]
      unless pendings.empty?
        puts
        puts "Pending:"
        pendings.each do |pending|
          puts color("  #{pending.description}", :pending)
        end
      end

      failures = @results[:fail]
      errors = @results[:error]

      unless failures.empty? && errors.empty?
        puts
        puts "Failures:"
        (failures + errors).each_with_index do |fail, i|
          if ex = fail.exception
            puts
            puts "  #{i + 1}) #{fail.description}"
            puts
            if msg = ex.message
              msg.split("\n").each do |line|
                print "       "
                unless ex.is_a?(AssertionFailed)
                  print color("Exception: ", :error)
                end
                puts color(line, :error)
              end
            end
            unless ex.is_a?(AssertionFailed)
              ex.backtrace.each do |trace|
                puts color("       #{trace}", :error)
              end
            end
          end
        end
      end

      puts

      success = @results[:success]
      total = pendings.length + failures.length + errors.length + success.length

      final_status = case
                     when (failures.length + errors.length) > 0 then :fail
                     when pendings.length > 0                   then :pending
                     else                                            :success
                     end

      puts "Finished in #{elapsed_time} seconds"
      puts color("#{total} examples, #{failures.length} failures, #{errors.length} errors, #{pendings.length} pending", final_status)
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
      (value - @expected).abs <= @delta
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

def pending(description, &block)
  Spec::RootContext.report(:pending, description)
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

fun main(argc : Int32, argv : UInt8**) : Int32
  GC.init
  time = Time.now
  CrystalMain.__crystal_main(argc, argv)
  elapsed_time = Time.now - time
  Spec::RootContext.print_results(elapsed_time)
  Spec::RootContext.succeeded ? 0 : 1
rescue ex
  puts ex
  1
end
