#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Code gen: fun" do
  it "call simple fun literal" do
    run("x = -> { 1 }; x.call").to_i.should eq(1)
  end

  it "call fun literal with arguments" do
    run("f = ->(x : Int32) { x + 1 }; f.call(41)").to_i.should eq(42)
  end

  it "call fun pointer" do
    run("def foo; 1; end; x = ->foo; x.call").to_i.should eq(1)
  end

  it "call fun pointer with args" do
    run("
      def foo(x, y)
        x + y
      end

      f = ->foo(Int32, Int32)
      f.call(1, 2)
    ").to_i.should eq(3)
  end

  pending "call fun pointer of instance method" do
    run("
      require "prelude"
      class Foo
        def initialize
          @x = 1
        end

        def coco
          puts "Hola"
          @x
        end
      end

      foo = Foo.new
      f = ->foo.coco
      f.call
    ").to_i.should eq(1)
  end

  it "codegens fun with another var" do
    run("
      def foo(x)
        bar(x, -> {})
      end

      def bar(x, proc)
      end

      foo(1)
      ")
  end

  it "codegens fun that returns a hierarchy type" do
    run("
      class Foo
        def coco; 1; end
      end

      class Bar < Foo
        def coco; 2; end
      end

      x = -> { Foo.new || Bar.new }
      x.call.coco
      ").to_i.should eq(1)
  end

  pending "codegens fun that accepts a union and is called with a single type" do
    run("
      f = ->(x : Int32 | Float64) { x + 1 }
      f.call(1).to_i
      ").to_i.should eq(2)
  end
end
