{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "autocast" do
    it "autocasts symbol to enum" do
      interpret(<<-CODE).should eq(1)
          enum Color
            Red
            Green
            Blue
          end

          def foo(x : Color)
            x
          end

          c = foo :green
          c.value
        CODE
    end

    it "autocasts number literal to integer" do
      interpret(<<-CODE).should eq(12)
          def foo(x : UInt8)
            x
          end

          foo(12)
        CODE
    end

    it "autocasts number literal to float" do
      interpret(<<-CODE).should eq(12.0)
          def foo(x : Float64)
            x
          end

          foo(12)
        CODE
    end

    it "autocasts symbol to enum in multidispatch (#11782)" do
      interpret(<<-CODE).should eq(1)
        enum Color
          Red
          Green
          Blue
        end

        class Foo
          def foo(x : Color)
            x
          end
        end

        class Bar
          def foo(x : Color)
            x
          end
        end

        (Foo.new || Bar.new).foo(:green).value
        CODE
    end

    it "autocasts int in multidispatch" do
      interpret(<<-CODE).should eq(1)
        class Foo
          def foo(x : Int64)
            x
          end
        end

        class Bar
          def foo(x : Int64)
            x
          end
        end

        (Foo.new || Bar.new).foo(1)
        CODE
    end
  end
end
