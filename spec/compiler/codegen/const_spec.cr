require "../../spec_helper"

describe "Codegen: const" do
  it "define a constant" do
    run("CONST = 1; CONST").to_i.should eq(1)
  end

  it "support nested constant" do
    run("class Foo; A = 1; end; Foo::A").to_i.should eq(1)
  end

  it "support constant inside a def" do
    run("
      class Foo
        A = 1

        def foo
          A
        end
      end

      Foo.new.foo
    ").to_i.should eq(1)
  end

  it "finds nearest constant first" do
    run("
      CONST = 1

      class Foo
        CONST = 2.5_f32

        def foo
          CONST
        end
      end

      Foo.new.foo
    ").to_f32.should eq(2.5)
  end

  it "allows constants with same name" do
    run("
      CONST = 1

      class Foo
        CONST = 2.5_f32

        def foo
          CONST
        end
      end

      CONST
      Foo.new.foo
    ").to_f32.should eq(2.5)
  end

  it "constants with expression" do
    run("
      CONST = 1 + 1
      CONST
    ").to_i.should eq(2)
  end

  it "finds global constant" do
    run("
      CONST = 1

      class Foo
        def foo
          CONST
        end
      end

      Foo.new.foo
    ").to_i.should eq(1)
  end

  it "define a constant in lib" do
    run("lib LibFoo; A = 1; end; LibFoo::A").to_i.should eq(1)
  end

  it "invokes block in const" do
    run("require \"prelude\"; CONST = [\"1\"].map { |x| x.to_i }; CONST[0]").to_i.should eq(1)
  end

  it "declare constants in right order" do
    run(%(
      CONST1 = 1 + 1
      CONST2 = true ? CONST1 : 0
      CONST2
      )).to_i.should eq(2)
  end

  it "uses correct types lookup" do
    run("
      module Moo
        class B
          def foo
            1
          end
        end

        C = B.new;
      end

      def foo
        Moo::C.foo
      end

      foo
      ").to_i.should eq(1)
  end

  it "codegens variable assignment in const" do
    run("
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      CONST = begin
            f = Foo.new(1)
            f
          end

      def foo
        CONST.x
      end

      foo
      ").to_i.should eq(1)
  end

  it "declaring var" do
    run("
      BAR = begin
        a = 1
        while 1 == 2
          b = 2
        end
        a
      end
      class Foo
        def compile
          BAR
        end
      end

      Foo.new.compile
      ").to_i.should eq(1)
  end

  it "initialize const that might raise an exception" do
    run("
      require \"prelude\"
      CONST = (raise \"OH NO\" if 1 == 2)

      def doit
        CONST
      rescue
      end

      doit.nil?
    ").to_b.should be_true
  end

  it "allows implicit self in constant, called from another class (bug)" do
    run("
      module Foo
        def self.foo
          1
        end

        A = foo
      end

      class Bar
        def bar
          Foo::A
        end
      end

      Bar.new.bar
      ").to_i.should eq(1)
  end

  it "codegens two consts with same variable name" do
    run("
      CONST1 = begin
            a = 1
          end

      CONST2 = begin
            a = 2.3
          end

      (CONST1 + CONST2).to_i
      ").to_i.should eq(3)
  end

  it "works with variable declared inside if" do
    run(%(
      FOO = begin
        if 1 == 2
          x = 3
        else
          x = 4
        end
        x
      end
      FOO
      )).to_i.should eq(4)
  end

  it "codegens constant that refers to another constant that is a struct" do
    run(%(
      struct Foo
        X = Foo.new(1)
        Y = X

        def initialize(@value : Int32)
        end

        def value
          @value
        end
      end

      Foo::Y.value
      )).to_i.should eq(1)
  end

  it "codegens constant that is declared later because of virtual dispatch" do
    run(%(
      class Base
        def base
        end
      end

      class Base2 < Base
        def base
        end
      end

      b = Base.new || Base2.new
      b.base

      class MyBase < Base
        CONST = 1

        def base
          CONST
        end
      end

      MyBase.new.base
      )).to_i.should eq(1)
  end

  it "doesn't crash if constant is used, but class is never instantiated (#1106)" do
    codegen(%(
      require "prelude"

      class Foo
        BAR = 1 || 2

        def foo
          BAR
        end
      end

      ->(x : Foo) { x.foo }
      ))
  end

  it "uses const before declaring it (hoisting)" do
    run(%(
      x = CONST

      CONST = foo

      def foo
        a = 1
        b = 2
        a + b
      end

      x
      )).to_i.should eq(3)
  end

  it "uses const before declaring it in another module" do
    run(%(
      require "prelude"

      def foo
        a = 1
        b = 2
        a + b
      end

      class Foo
        def self.foo
          CONST
        end
      end

      x = Foo.foo

      CONST = foo

      x
      )).to_i.should eq(3)
  end

  it "initializes simple const" do
    run(%(
      FOO = 10
      FOO
      )).to_i.should eq(10)
  end

  it "initializes simple const via another const" do
    run(%(
      BAR = 10
      FOO = BAR
      FOO
      )).to_i.should eq(10)
  end

  it "initializes ARGC_UNSAFE" do
    run(%(
      ARGC_UNSAFE
      )).to_i.should eq(0)
  end

  it "gets pointerof constant" do
    run(%(
      z = pointerof(FOO).value
      FOO = 10
      z
      )).to_i.should eq(10)
  end

  it "gets pointerof complex constant" do
    run(%(
      z = pointerof(FOO).value
      FOO = begin
        a = 10
        a
      end
      z
      )).to_i.should eq(10)
  end

  it "gets pointerof constant inside class" do
    run(%(
      require "prelude"

      class Foo
        BAR = 42

        @z : Int32

        def initialize
          @z = pointerof(BAR).value
        end

        def z
          @z
        end
      end

      Foo.new.z
      )).to_i.should eq(42)
  end

  it "inlines simple const" do
    mod = codegen(%(
      CONST = 1
      CONST
      ))

    mod.to_s.should_not contain("CONST")
  end

  it "inlines enum value" do
    mod = codegen(%(
      enum Foo
        CONST
      end

      Foo::CONST
      ))

    mod.to_s.should_not contain("CONST")
  end

  it "inlines const with math" do
    mod = codegen(%(
      CONST = (1 + 2) * 3
      ))

    mod.to_s.should_not contain("CONST")
  end

  it "inlines const referencing another const" do
    mod = codegen(%(
      OTHER = 1

      CONST = OTHER
      CONST
      ))

    mod.to_s.should_not contain("CONST")
    mod.to_s.should_not contain("OTHER")
  end

  it "inlines bool const" do
    mod = codegen(%(
      CONST = true
      CONST
      ))

    mod.to_s.should_not contain("CONST")
  end

  it "inlines char const" do
    mod = codegen(%(
      CONST = 'a'
      CONST
      ))

    mod.to_s.should_not contain("CONST")
  end
end
