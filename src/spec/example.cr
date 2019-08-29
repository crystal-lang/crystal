require "./item"

module Spec
  class Example
    include Item

    getter parent : Context
    getter block : ->
    getter? pending : Bool

    def initialize(@parent : Context, @description : String,
                   @file : String, @line : Int32, @end_line : Int32,
                   @block : ->, @pending : Bool)
    end

    def run
      Spec.root_context.check_nesting_spec(file, line) do
        Spec.formatters.each(&.before_example(description))

        if pending?
          Spec.root_context.report(:pending, description, file, line)
          return
        end

        start = Time.monotonic
        begin
          Spec.run_before_each_hooks
          block.call
          Spec.root_context.report(:success, description, file, line, Time.monotonic - start)
        rescue ex : Spec::AssertionFailed
          Spec.root_context.report(:fail, description, file, line, Time.monotonic - start, ex)
          Spec.abort! if Spec.fail_fast?
        rescue ex
          Spec.root_context.report(:error, description, file, line, Time.monotonic - start, ex)
          Spec.abort! if Spec.fail_fast?
        ensure
          Spec.run_after_each_hooks

          # We do this to give a chance for signals (like CTRL+C) to be handled,
          # which currently are only handled when there's a fiber switch
          # (IO stuff, sleep, etc.). Without it the user might wait more than needed
          # after pressing CTRL+C to quit the tests.
          Fiber.yield
        end
      end
    end
  end
end
