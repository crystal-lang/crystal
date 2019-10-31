module Spec
  class Example
    # Wraps an `Example` and a `Proc` that will eventually execute the
    # example.
    struct Procsy
      # The example that will eventually run when calling `run`.
      getter example : Example

      # :nodoc:
      def initialize(@example : Example, &@proc : ->)
      end

      # Executes the wrapped example, possibly executing other
      # `around_each` hooks before that.
      def run
        @proc.call
      end
    end
  end
end
