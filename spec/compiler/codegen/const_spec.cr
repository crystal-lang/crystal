require "../../spec_helper"

describe "Codegen: const" do
  it "define a constant" do
    run("A = 1; A").to_i.should eq(1)
  end

  it "support nested constant" do
    run("class B; A = 1; end; B::A").to_i.should eq(1)
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
      A = 1

      class Foo
        A = 2.5_f32

        def foo
          A
        end
      end

      Foo.new.foo
    ").to_f32.should eq(2.5)
  end

  it "allows constants with same name" do
    run("
      A = 1

      class Foo
        A = 2.5_f32

        def foo
          A
        end
      end

      A
      Foo.new.foo
    ").to_f32.should eq(2.5)
  end

  it "constants with expression" do
    run("
      A = 1 + 1
      A
    ").to_i.should eq(2)
  end

  it "finds global constant" do
    run("
      A = 1

      class Foo
        def foo
          A
        end
      end

      Foo.new.foo
    ").to_i.should eq(1)
  end

  it "define a constant in lib" do
    run("lib LibFoo; A = 1; end; LibFoo::A").to_i.should eq(1)
  end

  it "invokes block in const" do
    run("require \"prelude\"; A = [\"1\"].map { |x| x.to_i }; A[0]").to_i.should eq(1)
  end

  it "declare constants in right order" do
    run(%(
      A = 1 + 1
      B = true ? A : 0
      B
      )).to_i.should eq(2)
  end

  it "uses correct types lookup" do
    run("
      module A
        class B
          def foo
            1
          end
        end

        C = B.new;
      end

      def foo
        A::C.foo
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

      A = begin
            f = Foo.new(1)
            f
          end

      def foo
        A.x
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
      A = begin
            a = 1
          end

      B = begin
            a = 2.3
          end

      (A + B).to_i
      ").to_i.should eq(3)
  end

  it "works with const initialized after global variable" do
    run(%(
      $a = 1
      COCO = $a
      COCO
      )).to_i.should eq(1)
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
      x = A

      A = foo

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
          A
        end
      end

      x = Foo.foo

      A = foo

      x
      )).to_i.should eq(3)
  end

  it "initializes const the moment it reaches it" do
    run(%(
      $x = 10
      FOO = begin
        a = $x
        a
      end
      w = FOO
      z = FOO
      z
      )).to_i.should eq(10)
  end

  it "initializes const when read" do
    run(%(
      $x = 10
      z = FOO
      FOO = begin
        a = $x
        a
      end
      z
      )).to_i.should eq(10)
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
end
