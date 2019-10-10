module Spec
  class Example
    struct Procsy
      def initialize(@proc : ->)
      end

      def initialize(&@proc : ->)
      end

      def run
        @proc.call
      end
    end
  end
end
