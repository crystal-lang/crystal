require "../../spec_helper"

describe "Codegen: const" do
  it "define a constant" do
    expect(run("A = 1; A").to_i).to eq(1)
  end

  it "support nested constant" do
    expect(run("class B; A = 1; end; B::A").to_i).to eq(1)
  end

  it "support constant inside a def" do
    expect(run("
      class Foo
        A = 1

        def foo
          A
        end
      end

      Foo.new.foo
    ").to_i).to eq(1)
  end

  it "finds nearest constant first" do
    expect(run("
      A = 1

      class Foo
        A = 2.5_f32

        def foo
          A
        end
      end

      Foo.new.foo
    ").to_f32).to eq(2.5)
  end

  it "allows constants with same name" do
    expect(run("
      A = 1

      class Foo
        A = 2.5_f32

        def foo
          A
        end
      end

      A
      Foo.new.foo
    ").to_f32).to eq(2.5)
  end

  it "constants with expression" do
    expect(run("
      A = 1 + 1
      A
    ").to_i).to eq(2)
  end

  it "finds global constant" do
    expect(run("
      A = 1

      class Foo
        def foo
          A
        end
      end

      Foo.new.foo
    ").to_i).to eq(1)
  end

  it "define a constant in lib" do
    expect(run("lib LibFoo; A = 1; end; LibFoo::A").to_i).to eq(1)
  end

  it "invokes block in const" do
    expect(run("require \"prelude\"; A = [\"1\"].map { |x| x.to_i }; A[0]").to_i).to eq(1)
  end

  it "declare constants in right order" do
    expect(run(%(
      A = 1 + 1
      B = true ? A : 0
      B
      )).to_i).to eq(2)
  end

  it "uses correct types lookup" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "codegens variable assignment in const" do
    expect(run("
      class Foo
        def initialize(@x)
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
      ").to_i).to eq(1)
  end

  it "declaring var" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "initialize const that might raise an exception" do
    expect(run("
      require \"prelude\"
      CONST = (raise \"OH NO\" if 1 == 2)

      def doit
        CONST
      rescue
      end

      doit.nil?
    ").to_b).to be_true
  end

  it "allows implicit self in constant, called from another class (bug)" do
    expect(run("
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
      ").to_i).to eq(1)
  end

  it "codegens two consts with same variable name" do
    expect(run("
      A = begin
            a = 1
          end

      B = begin
            a = 2.3
          end

      (A + B).to_i
      ").to_i).to eq(3)
  end

  it "works with const initialized after global variable" do
    expect(run(%(
      $a = 1
      COCO = $a
      COCO
      )).to_i).to eq(1)
  end

  it "works with variable declared inside if" do
    expect(run(%(
      FOO = begin
        if 1 == 2
          x = 3
        else
          x = 4
        end
        x
      end
      FOO
      )).to_i).to eq(4)
  end

  it "codegens constant that refers to another constant that is a struct" do
    expect(run(%(
      struct Foo
        X = Foo.new(1)
        Y = X

        def initialize(@value)
        end

        def value
          @value
        end
      end

      Foo::Y.value
      )).to_i).to eq(1)
  end

  it "codegens constant that is declared later because of virtual dispatch" do
    expect(run(%(
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
      )).to_i).to eq(1)
  end
end
