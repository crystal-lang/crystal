require "./item"

module Spec
  # Each example (`it`) in a spec suite.
  class Example
    include Item

    # :nodoc:
    getter block : (->) | Nil

    # :nodoc:
    def initialize(@parent : Context, @description : String,
                   @file : String, @line : Int32, @end_line : Int32,
                   @focus : Bool, tags,
                   @block : (->) | Nil)
      initialize_tags(tags)
    end

    # :nodoc:
    def run
      Spec.root_context.check_nesting_spec(file, line) do
        Spec.formatters.each(&.before_example(description))

        unless block = @block
          @parent.report(:pending, description, file, line)
          return
        end

        non_nil_block = block
        start = Time.monotonic

        ran = @parent.run_around_each_hooks(Example::Procsy.new(self) { internal_run(start, non_nil_block) })
        ran || internal_run(start, non_nil_block)

        # We do this to give a chance for signals (like CTRL+C) to be handled,
        # which currently are only handled when there's a fiber switch
        # (IO stuff, sleep, etc.). Without it the user might wait more than needed
        # after pressing CTRL+C to quit the tests.
        Fiber.yield
      end
    end

    private def internal_run(start, block)
      @parent.run_before_each_hooks
      block.call
      @parent.report(:success, description, file, line, Time.monotonic - start)
    rescue ex : Spec::AssertionFailed
      @parent.report(:fail, description, file, line, Time.monotonic - start, ex)
      Spec.abort! if Spec.fail_fast?
    rescue ex : Spec::ExamplePending
      @parent.report(:pending, description, file, line, Time.monotonic - start)
    rescue ex
      @parent.report(:error, description, file, line, Time.monotonic - start, ex)
      Spec.abort! if Spec.fail_fast?
    ensure
      @parent.run_after_each_hooks
    end
  end
end

require "./example/procsy"
