{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "responds_to?" do
    it "does responds_to?" do
      interpret(<<-CRYSTAL).should eq(3)
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
        CRYSTAL
    end

    it "doesn't crash if def body ends up with no type (#12219)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("1")
        class Base
          def foo
            raise "OH NO"
          end
        end

        module Moo
          def foo
            if self.responds_to?(:bar)
              self.bar
            else
              super &- 0_i64
            end
          end
        end

        class Child < Base
          include Moo
        end

        begin
          Child.new.foo
          0
        rescue
          1
        end
        CRYSTAL
    end
  end
end
