module Spec
  class ExampleGroup < Context
    # Wraps an `ExampleGroup` and a `Proc` that will eventually execute the
    # group.
    struct Procsy
      # The group that will eventually run when calling `run`.
      getter example_group : ExampleGroup

      # :nodoc:
      def initialize(@example_group : ExampleGroup, &@proc : ->)
      end

      # Executes the wrapped example group, possibly executing other
      # `around_all` hooks before that.
      def run
        @proc.call
      end
    end
  end
end
