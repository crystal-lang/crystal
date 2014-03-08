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

  it "codegens closure with redefined var" do
    run("
      a = true
      a = 1
      f = ->{ a + 1 }
      f.call
      ").to_i.should eq(2)
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
end
