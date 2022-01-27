{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "classes" do
    it "does allocate, set instance var and get instance var" do
      interpret(<<-CODE).should eq(42)
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
      CODE
    end

    it "does constructor" do
      interpret(<<-CODE).should eq(42)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        foo = Foo.new(42)
        foo.x
      CODE
    end

    it "interprets read instance var" do
      interpret(%(x = "hello".@c)).should eq('h'.ord)
    end

    it "discards allocate" do
      interpret(<<-CODE).should eq(3)
        class Foo
        end

        Foo.allocate
        3
      CODE
    end

    it "calls implicit class self method" do
      interpret(<<-CODE).should eq(10)
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
      CODE
    end

    it "calls explicit struct self method" do
      interpret(<<-CODE).should eq(10)
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
      CODE
    end

    it "calls implicit struct self method" do
      interpret(<<-CODE).should eq(10)
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
      CODE
    end

    it "does object_id" do
      interpret(<<-CODE).should be_true
        class Foo
        end

        foo = Foo.allocate
        object_id = foo.object_id
        address = foo.as(Void*).address
        object_id == address
      CODE
    end
  end
end
