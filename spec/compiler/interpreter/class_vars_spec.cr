{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "class vars" do
    it "interprets class var without initializer" do
      interpret(<<-CODE).should eq(41)
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
      CODE
    end

    it "interprets class var with initializer" do
      interpret(<<-CODE).should eq(42)
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
      CODE
    end

    it "interprets class var for virtual type" do
      interpret(<<-CODE).should eq(30)
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
      CODE
    end

    it "interprets class var for virtual metaclass type" do
      interpret(<<-CODE).should eq(30)
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
      CODE
    end

    it "finds self in class var initializer (#12439)" do
      interpret(<<-CODE).should eq(42)
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
      CODE
    end
  end
end
