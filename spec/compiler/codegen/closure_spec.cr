#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: closure" do
  it "codegens simple closure at global scope" do
    run("
      a = 1
      foo = ->{ a }
      foo.call
    ").to_i.should eq(1)
  end

  it "codegens simple closure in function" do
    run("
      def foo
        a = 1
        ->{ a }
      end

      foo.call
    ").to_i.should eq(1)
  end

  it "codegens simple closure in function with argument" do
    run("
      def foo(a)
        ->{ a }
      end

      foo(1).call
    ").to_i.should eq(1)
  end

  it "codegens simple closure in block" do
    run("
      def foo
        yield
      end

      f = foo do
        x = 1
        -> { x }
      end

      f.call
    ").to_i.should eq(1)
  end

  it "codegens closured nested in block" do
    run("
      def foo
        yield
      end

      a = 1
      f = foo do
        b = 2
        -> { a + b }
      end
      f.call
    ").to_i.should eq(3)
  end

  it "codegens closured nested in block with a call with a closure with same names" do
    run("
      def foo
        a = 3
        f = -> { a }
        yield f.call
      end

      a = 1
      f = foo do |x|
        -> { a + x }
      end
      f.call
    ").to_i.should eq(4)
  end

  it "codegens closure with block that declares same var" do
    run("
      def foo
        a = 1
        yield a
      end

      f = foo do |x|
        a = 2
        -> { a + x }
      end
      f.call
      ").to_i.should eq(3)
  end

  it "codegens closure with def that has an if" do
    run("
      def foo
        yield 1 if 1
        yield 2
      end

      f = foo do |x|
        -> { x }
      end
      f.call
      ").to_i.should eq(2)
  end

  it "codegens multiple nested blocks" do
    run("
      def foo
        yield 1
        yield 2
        yield 3
      end

      a = 1
      f = foo do |x|
        b = 1
        foo do |y|
          c = 1
          -> { a + b + c + x + y }
        end
      end
      f.call
      ").to_i.should eq(9)
  end

  it "codegens closure with nested context without new closured vars" do
    run("
      def foo
        yield
      end

      a = 1
      f = foo do
        -> { a }
      end
      f.call
      ").to_i.should eq(1)
  end

  it "codegens closure with nested context without new closured vars" do
    run("
      def foo
        yield
      end

      def bar
        yield
      end

      a = 1
      f = foo do
        b = 1
        bar do
          -> { a + b }
        end
      end
      f.call
      ").to_i.should eq(2)
  end

  it "codegens closure with nested context without new closured vars but with block arg" do
    run("
      def foo
        yield
      end

      def bar
        yield 3
      end

      a = 1
      f = foo do
        b = 1
        bar do |x|
          x
          -> { a + b }
        end
      end
      f.call
      ").to_i.should eq(2)
  end

  it "unifies types of closured var" do
    run("
      a = 1
      f = -> { a }
      a = 2.5
      f.call.to_i
      ").to_i.should eq(2)
  end

  it "codegens closure with block" do
    run("
      def foo
        yield
      end

      a = 1
      ->{ foo { a } }.call
      ").to_i.should eq(1)
  end

  # pending "transforms block to fun literal" do
  #   run("
  #     def foo(&block : Int32 ->)
  #       block.call(1)
  #     end

  #     foo do |x|
  #       x + 1
  #     end
  #     ").to_i.should eq(2)
  # end
end
