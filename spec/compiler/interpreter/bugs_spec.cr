{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "bugs" do
    it "doesn't pass self to top-level method" do
      interpret(<<-CRYSTAL).should eq(1)
        struct Int32
          def foo(x)
            self
          end
        end

        def value
          1
        end

        module Moo
          def self.moo
            1.foo(value)
          end
        end

        Moo.moo
      CRYSTAL
    end

    it "doesn't pass self to top-level method (FileNode)" do
      interpret(<<-CRYSTAL).should eq(1)
        enum Color
          Red
          Green
          Blue
        end

        class Object
          def should(expectation)
            self
          end
        end

        def eq(value)
          value
        end

        private def t(type : Color)
          type
        end

        other = 2
        e = Color::Green.should eq(t :green)
        e.value
      CRYSTAL
    end

    it "breaks from current block, not from outer block" do
      interpret(<<-CRYSTAL).should eq(2)
        def twice
          # index: 1, block_caller: 0

          yield
          yield
        end

        def bar
          # index: 4, block_caller: 3
          yield
        end

        def foo
          # index: 3, block_caller: 2
          bar do
            # index: 5, block_caller: 2
            yield
          end
        end

        # index: 0

        x = 0

        twice do
          # index: 2
          x += 1
          foo do
            # index: 6

            # parent frame has block_caller: 2,
            # that's where we have to go to
            break
          end
        end

        x
      CRYSTAL
    end

    it "doesn't incorrectly consider a non-closure as closure" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("false")
        c = 0
        ->{
          c
          ->{}.closure?
        }.call
      CRYSTAL
    end

    it "doesn't override local variable value with block var with the same name" do
      interpret(<<-CRYSTAL).should eq(0)
        def block
          yield 1
        end

        def block2
          yield 10
        end

        def foo
          block do |i|
          end

          i = 0
          block2 do |x|
            i
          end
        end

        foo
      CRYSTAL
    end

    it "does leading zeros" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("8")
        0_i8.leading_zeros_count
      CRYSTAL
    end

    it "does multidispatch on virtual struct" do
      interpret(<<-CRYSTAL).should eq(true)
        abstract struct Base
        end

        struct Foo < Base
          @x : Int32 | Char

          def initialize
            @x = 0
          end

          def foo
            @x.is_a?(Int32)
          end
        end

        struct Bar < Base
          def foo
            false
          end
        end

        address = Foo.new.as(Base)
        address.foo
      CRYSTAL
    end

    it "correctly puts virtual metaclass type in union" do
      interpret(<<-CRYSTAL).should eq("Bar")
        abstract struct Foo
        end

        struct Bar < Foo
        end

        struct Baz < Foo
        end

        class Class
          def name : String
            {{ @type.name.stringify }}
          end
        end

        foo = Bar.new.as(Foo)
        foo2 = foo || nil
        foo2.class.name
      CRYSTAL
    end

    it "does multidispatch on virtual struct union nil" do
      interpret(<<-CRYSTAL).should eq(true)
        abstract struct Foo
          @value = 1
        end

        struct Bar < Foo
        end

        struct Baz < Foo
        end

        class Object
          def itself
            a = 1
            self
          end
        end

        foo = Bar.new.as(Foo)
        bar = (foo || nil).itself
        bar.is_a?(Bar)
     CRYSTAL
    end
  end
end
