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

    it "autocasts symbol to enum in ivar initializer (#12216)" do
      interpret(<<-CODE).should eq(2)
          enum Color
            Red
            Green
            Blue
          end

          class Foo
            @color : Color = :blue

            def color
              @color
            end
          end

          foo = Foo.new
          foo.color.value
        CODE
    end

    it "autocasts integer var to integer (#12560)" do
      interpret(<<-CODE).should eq(1)
        def foo(x : Int64)
          x
        end

        x = 1
        foo(x)
        CODE
    end

    it "autocasts integer var to float (#12560)" do
      interpret(<<-CODE).should eq(1)
        def foo(x : Float64)
          x
        end

        x = 1
        foo(x)
        CODE
    end

    it "autocasts float32 var to float64 (#12560)" do
      interpret(<<-CODE).should eq(1)
        def foo(x : Float64)
          x
        end

        x = 1.0_f32
        foo(x)
        CODE
    end
  end
end
