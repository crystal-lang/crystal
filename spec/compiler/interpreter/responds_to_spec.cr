{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "responds_to?" do
    it "does responds_to?" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def foo
            @x
          end
        end

        class Bar
          def initialize
            @x = 1
            @y = 2
          end

          def bar
            @y
          end
        end

        a = 0
        foo = Foo.new || Bar.new
        if foo.responds_to?(:foo)
          a += foo.foo
        end

        bar = Bar.new || Foo.new
        if bar.responds_to?(:bar)
          a += bar.bar
        end

        a
        CODE
    end
  end
end
