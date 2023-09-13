{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "class vars" do
    it "interprets class var without initializer" do
      interpret(<<-CRYSTAL).should eq(41)
        class Foo
          @@x : Int32?

          def set
            @@x = 41
          end

          def get
            @@x
          end
        end

        foo = Foo.new

        a = 0

        x = foo.get
        a += 1 if x

        foo.set

        x = foo.get
        a += x if x

        a
      CRYSTAL
    end

    it "interprets class var with initializer" do
      interpret(<<-CRYSTAL).should eq(42)
        class Foo
          @@x = 10

          def set
            @@x = 32
          end

          def get
            @@x
          end
        end

        foo = Foo.new

        a = 0

        x = foo.get
        a += x if x

        foo.set

        x = foo.get
        a += x if x

        a
      CRYSTAL
    end

    it "interprets class var for virtual type" do
      interpret(<<-CRYSTAL).should eq(30)
        class Foo
          @@x = 1

          def set(@@x)
          end

          def get
            @@x
          end
        end

        class Bar < Foo
        end

        foo = Foo.new
        bar = Bar.new

        foobar = foo || bar
        foobar.set(10)

        barfoo = bar || foo
        barfoo.set(20)

        a = 0
        a += foobar.get
        a += barfoo.get
        a
      CRYSTAL
    end

    it "interprets class var for virtual metaclass type" do
      interpret(<<-CRYSTAL).should eq(30)
        class Foo
          @@x = 1

          def self.set(@@x)
          end

          def self.get
            @@x
          end
        end

        class Bar < Foo
        end

        foo = Foo
        bar = Bar

        foobar = foo || bar
        foobar.set(10)

        barfoo = bar || foo
        barfoo.set(20)

        a = 0
        a += foobar.get
        a += barfoo.get
        a
      CRYSTAL
    end

    it "finds self in class var initializer (#12439)" do
      interpret(<<-CRYSTAL).should eq(42)
        class Foo
          @@value : Int32 = self.int

          def self.value
            @@value
          end

          def self.int
            42
          end
        end

        Foo.value
      CRYSTAL
    end

    it "does class var initializer with union (#12633)" do
      interpret(<<-CRYSTAL).should eq("hello")
        class MyClass
          @@a : String | Int32 = "hello"

          def self.a
            @@a
          end
        end

        x = MyClass.a
        case x
        in String
          x
        in Int32
          "bye"
        end
        CRYSTAL
    end

    it "reads class var initializer with union (#12633)" do
      interpret(<<-CRYSTAL).should eq(2)
        class MyClass
          @@a : Char | Int32 = 1

          def self.foo(a)
            @@a = a
            b = @@a
            case b
            in Char
              3
            in Int32
              b
            end
          end
        end

        MyClass.foo(2)
        CRYSTAL
    end
  end
end
