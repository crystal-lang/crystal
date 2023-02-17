{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "classes" do
    it "does allocate, set instance var and get instance var" do
      interpret(<<-CRYSTAL).should eq(42)
        class Foo
          @x = 0

          def x=(@x)
          end

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x = 42
        foo.x
      CRYSTAL
    end

    it "does constructor" do
      interpret(<<-CRYSTAL).should eq(42)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        foo = Foo.new(42)
        foo.x
      CRYSTAL
    end

    it "interprets read instance var" do
      interpret(%(x = "hello".@c)).should eq('h'.ord)
    end

    it "discards allocate" do
      interpret(<<-CRYSTAL).should eq(3)
        class Foo
        end

        Foo.allocate
        3
      CRYSTAL
    end

    it "calls implicit class self method" do
      interpret(<<-CRYSTAL).should eq(10)
        class Foo
          def initialize
            @x = 10
          end

          def foo
            bar
          end

          def bar
            @x
          end
        end

        foo = Foo.new
        foo.foo
      CRYSTAL
    end

    it "calls explicit struct self method" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 10
          end

          def foo
            self.bar
          end

          def bar
            @x
          end
        end

        foo = Foo.new
        foo.foo
      CRYSTAL
    end

    it "calls implicit struct self method" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 10
          end

          def foo
            bar
          end

          def bar
            @x
          end
        end

        foo = Foo.new
        foo.foo
      CRYSTAL
    end

    it "does object_id" do
      interpret(<<-CRYSTAL).should be_true
        class Foo
        end

        foo = Foo.allocate
        object_id = foo.object_id
        address = foo.as(Void*).address
        object_id == address
      CRYSTAL
    end
  end

  it "inlines instance var access from virtual type with a single type (#39520)" do
    interpret(<<-CRYSTAL).should eq(1)
        struct Int32
          def foo
            1
          end
        end

        struct Char
          def foo
            2
          end
        end

        abstract class Expression
        end

        class ValueExpression < Expression
          def initialize
            @value = 1 || 'a'
          end

          def value
            @value
          end
        end

        expression = ValueExpression.new.as(Expression)
        expression.value.foo
      CRYSTAL
  end

  it "downcasts virtual type to its only type (#12351)" do
    interpret(<<-CRYSTAL).should eq(1)
      abstract class A
      end

      class B < A
        def x
          1
        end
      end

      def foo(b : B)
        b = 1
      end

      b = B.new.as(A)
      foo(b)
      CRYSTAL
  end
end
