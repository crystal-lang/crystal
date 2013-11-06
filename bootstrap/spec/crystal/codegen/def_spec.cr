#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Code gen: def" do
  it "codegens def" do
    run("
      def foo
        1
      end

      foo
      ").to_i.should eq(1)
  end

  it "codegens def with argument" do
    run("
      def foo(x)
        x
      end

      foo(1)
      ").to_i.should eq(1)
  end

  it "codegens class def" do
    run("
      class Foo
        def self.foo
          1
        end
      end

      Foo.foo
      ").to_i.should eq(1)
  end

  it "codegens def which changes type of arg" do
    run("
      def foo(x)
        while x >= 0
          x = -0.5
        end
        x
      end

      foo(2).to_i
    ").to_i.should eq(0)
  end
end
