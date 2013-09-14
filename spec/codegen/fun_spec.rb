require 'spec_helper'

describe 'Code gen: fun' do
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
    run(%(
      def foo(x, y)
        x + y
      end

      f = ->foo(Int32, Int32)
      f.call(1, 2)
    )).to_i.should eq(3)
  end

  pending "call fun pointer of instance method" do
    run(%(
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
    )).to_i.should eq(1)
  end
end
