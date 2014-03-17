#!/usr/bin/env bin/crystal --run
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
    run("lib Foo; A = 1; end; Foo::A").to_i.should eq(1)
  end

  it "invokes block in const" do
    run("require \"prelude\"; A = [\"1\"].map { |x| x.to_i }; A[0]").to_i.should eq(1)
  end

  it "declare constants in right order" do
    run("A = 1 + 1; B = true ? A : 0; B").to_i.should eq(2)
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
end
