require "./item"

module Spec
  class Example
    include Item

    getter block : (->) | Nil

    def initialize(@parent : Context, @description : String,
                   @file : String, @line : Int32, @end_line : Int32,
                   @focus : Bool,
                   @block : (->) | Nil)
    end

    def run
      Spec.root_context.check_nesting_spec(file, line) do
        Spec.formatters.each(&.before_example(description))

        unless block = @block
          @parent.report(:pending, description, file, line)
          return
        end

        start = Time.monotonic
        begin
          Spec.run_before_each_hooks
          block.call
          @parent.report(:success, description, file, line, Time.monotonic - start)
        rescue ex : Spec::AssertionFailed
          @parent.report(:fail, description, file, line, Time.monotonic - start, ex)
          Spec.abort! if Spec.fail_fast?
        rescue ex
          @parent.report(:error, description, file, line, Time.monotonic - start, ex)
          Spec.abort! if Spec.fail_fast?
        ensure
          Spec.run_after_each_hooks

          {% unless flag?(:win32) %}
            # We do this to give a chance for signals (like CTRL+C) to be handled,
            # which currently are only handled when there's a fiber switch
            # (IO stuff, sleep, etc.). Without it the user might wait more than needed
            # after pressing CTRL+C to quit the tests.
            Fiber.yield
          {% end %}
        end
      end
    end
  end
end
