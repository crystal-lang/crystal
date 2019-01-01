require "spec"

private SAMPLE_SPEC_FILE = "foo_spec.cr"

class DummyRootContext < Spec::RootContext
  @io = String::Builder.new

  property lines = {} of {String, Int32} => String

  delegate puts, print, to: @io

  def output
    @io.to_s
  end

  def report(result)
    # Spec.formatters.each(&.report(result))

    @results[result.kind] << result
  end

  private def read_line(file, line)
    lines[{file, line}]?
  end
end

class DummyFormatter < Spec::Formatter
  getter results = [] of Spec::Result

  def report(result)
    @results << result
  end

  def finish
    puts
  end
end

private class SpecEnvironment
  getter root = DummyRootContext.new
  getter formatters

  def initialize(@formatters = [DummyFormatter.new])
    @contexts_stack = [@root] of Spec::Context
  end

  def self.run(elapsed_time = 42.milliseconds, use_color = false)
    instance = new

    old_color = Spec.use_colors?
    begin
      Spec.use_colors = use_color

      yield instance

      instance.@root.print_results(elapsed_time)
    ensure
      Spec.use_colors = old_color
    end

    instance.@root.output
  end

  def describe(description, file, line, &block)
    describe = Spec::NestedContext.new(description, file, line, @contexts_stack.last)
    @contexts_stack.push describe
    @formatters.each(&.push(describe))
    block.call
    @formatters.each(&.pop)
    @contexts_stack.pop
  end

  def it(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    @formatters.each(&.before_example(description))

    start = Time.monotonic
    begin
      # Spec.run_before_each_hooks
      block.call
      report(:success, description, file, line, Time.monotonic - start)
    rescue ex : Spec::AssertionFailed
      report(:fail, description, file, line, Time.monotonic - start, ex)
      # Spec.abort! if Spec.fail_fast?
    rescue ex
      report(:error, description, file, line, Time.monotonic - start, ex)
      # Spec.abort! if Spec.fail_fast?
    ensure
      # Spec.run_after_each_hooks
    end
  end

  private def report(kind, full_description, file, line, elapsed = nil, ex = nil)
    result = Spec::Result.new(kind, full_description, file, line, elapsed, ex)
    @contexts_stack.last.report(result)
  end

  def pending(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    @formatters.each(&.before_example(description))

    @root.report(:pending, description, file, line)
  end
end

describe "spec output" do
  it "empty example" do
    output = SpecEnvironment.run do |env|
      env.describe "foo test", SAMPLE_SPEC_FILE, 3 do
        env.it "passes a test", SAMPLE_SPEC_FILE, 4, 5 { }
      end

      # env.formatters.first.as(DummyFormatter).results.map(&.kind).should eq [:success]
    end

    output.should eq <<-'RESULT'

      Finished in 42.0 milliseconds
      1 examples, 0 failures, 0 errors, 0 pending

      RESULT
  end

  it "failing example" do
    output = SpecEnvironment.run do |env|
      env.root.lines[{SAMPLE_SPEC_FILE, 5}] = "3.should eq 4"
      env.describe "foo test", SAMPLE_SPEC_FILE, 3 do
        env.it "passes a test", SAMPLE_SPEC_FILE, 4, 6 do
          3.should eq(4), SAMPLE_SPEC_FILE, 5
        end
      end

      # env.formatters.first.as(DummyFormatter).results.map(&.kind).should eq [:success]
    end

    output.should eq <<-'RESULT'

      Failures:

        1) foo test passes a test
           Failure/Error: 3.should eq 4

             Expected: 4
                  got: 3

           # foo_spec.cr:5

      Finished in 42.0 milliseconds
      1 examples, 1 failures, 0 errors, 0 pending

      Failed examples:

      crystal spec foo_spec.cr:4 # foo test passes a test

      RESULT
  end

  it "raising example" do
    output = SpecEnvironment.run do |env|
      env.describe "foo test", SAMPLE_SPEC_FILE, 3 do
        env.it "passes a test", SAMPLE_SPEC_FILE, 4, 5 do
          raise "unexpected exception"
        end
      end

      # env.formatters.first.as(DummyFormatter).results.map(&.kind).should eq [:success]
    end

    intro, search, rest = output.partition "unexpected exception"

    (intro + search).should eq <<-'RESULT'

      Failures:

        1) foo test passes a test

             unexpected exception
      RESULT

    callstack, search, outro = rest.partition("Finished in 42.0 milliseconds")
    (search + outro).should eq <<-'RESULT'
      Finished in 42.0 milliseconds
      1 examples, 0 failures, 1 errors, 0 pending

      Failed examples:

      crystal spec foo_spec.cr:4 # foo test passes a test

      RESULT
  end
end
