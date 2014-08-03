#!/usr/bin/env bin/crystal --run
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

  it "call fun pointer of instance method" do
    run(%(
      class Foo
        def initialize
          @x = 1
        end

        def coco
          @x
        end
      end

      foo = Foo.new
      f = ->foo.coco
      f.call
    )).to_i.should eq(1)
  end

  it "call fun pointer of instance method that raises" do
    run(%(
      require "prelude"
      class Foo
        def coco
          raise "foo"
        end
      end

      foo = Foo.new
      f = ->foo.coco
      f.call rescue 1
    )).to_i.should eq(1)
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

  it "codegens fun that returns a virtual type" do
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

  it "makes sure that fun pointer is transformed after type inference" do
    run("
      require \"prelude\"

      class B
        def initialize(@x)
        end
        def x
          @x
        end
      end

      class A
        def on_something
          B.new(1)
        end
      end

      def _on_(p : A*)
        p.value.on_something.x
      end

      c = ->_on_(A*)
      a = A.new
      c.call(pointerof(a))
      ").to_i.should eq(1)
  end

  it "binds function pointer to associated call" do
    run("
      class A
        def initialize(@e : Int32)
        end

        def on_something
          @e
        end
      end

      def _on_(p : A*)
        p.value.on_something
      end

      c = ->_on_(A*)
      a = A.new(12)
      a.on_something

      c.call(pointerof(a))
      ").to_i.should eq(12)
  end

  it "call simple fun literal with return" do
    run("x = -> { return 1 }; x.call").to_i.should eq(1)
  end

  it "calls fun pointer with union (passed by value) arg" do
    run("
      struct Number
        def abs; self; end
      end

      f = ->(x : Int32 | Float64) { x.abs }
      f.call(1 || 1.5).to_i
      ").to_i.should eq(1)
  end

  it "allows passing fun type to C automatically" do
    run(%(
      require "prelude"

      lib C
        fun qsort(base : Void*, nel : C::SizeT, width : C::SizeT, callback : (Void*, Void* -> Int32))
      end

      ary = [3, 1, 4, 2]
      C.qsort(ary.buffer as Void*, ary.length.to_sizet, sizeof(Int32).to_sizet, ->(a : Void*, b : Void*) {
        a = a as Int32*
        b = b as Int32*
        a.value <=> b.value
      })
      ary[0]
      )).to_i.should eq(1)
  end

  it "allows fun pointer where self is a class" do
    run("
      class A
        def self.bla
          1
        end
      end

      f = ->A.bla
      f.call
      ").to_i.should eq(1)
  end

  it "codegens fun literal hard type inference (1)" do
    run(%(
      require "prelude"

      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      def foo(s)
        Foo.new(s.x)
      end

      def bar
        ->(s : Foo) { ->foo(Foo) }
      end

      bar

      1
      )).to_i.should eq(1)
  end

  it "automatically casts fun that returns something to fun that returns void" do
    run("
      $a = 0

      def foo(x : ->)
        x.call
      end

      foo ->{ $a = 1 }

      $a
      ").to_i.should eq(1)
  end

  it "allows fun type of enum type" do
    run("
      lib Foo
        enum MyEnum
          X = 1
        end
      end

      ->(x : Foo::MyEnum) {
        x
      }.call(Foo::MyEnum::X)
      ").to_i.should eq(1)
  end

  it "allows fun type of enum type with base type" do
    run("
      lib Foo
        enum MyEnum < UInt16
          X = 1
        end
      end

      ->(x : Foo::MyEnum) {
        x
      }.call(Foo::MyEnum::X)
      ").to_i.should eq(1)
  end

  it "codegens nilable fun type (1)" do
    run("
      a = 1 == 2 ? nil : ->{ 3 }
      if a
        a.call
      else
        4
      end
      ").to_i.should eq(3)
  end

  it "codegens nilable fun type (2)" do
    run("
      a = 1 == 1 ? nil : ->{ 3 }
      if a
        a.call
      else
        4
      end
      ").to_i.should eq(4)
  end

  it "codegens nilable fun type dispatch (1)" do
    run("
      def foo(x : -> U)
        x.call
      end

      def foo(x : Nil)
        0
      end

      a = 1 == 1 ? (->{ 3 }) : nil
      foo(a)
      ").to_i.should eq(3)
  end

  it "codegens nilable fun type dispatch (2)" do
    run("
      def foo(x : -> U)
        x.call
      end

      def foo(x : Nil)
        0
      end

      a = 1 == 1 ? nil : ->{ 3 }
      foo(a)
      ").to_i.should eq(0)
  end

  it "builds fun type from fun" do
    build("
      lib C
        fun foo : ->
      end

      x = C.foo
      x.call
      ")
  end

  it "builds nilable fun type from fun" do
    build("
      lib C
        fun foo : (->)?
      end

      x = C.foo
      if x
        x.call
      end
      ")
  end

  it "assigns nil and fun to nilable fun type" do
    run("
      class Foo
        def initialize
        end

        def x=(@x)
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x = nil
      foo.x = -> { 1 }
      z = foo.x
      if z
        z.call
      else
        2
      end
      ").to_i.should eq(1)
  end

  it "allows invoking fun literal with smaller type" do
    run("
      struct Nil
        def to_i
          0
        end
      end

      f = ->(x : Int32 | Nil) {
        x
      }
      f.call(1).to_i
      ").to_i.should eq(1)
  end

  it "does closure? false" do
    run("
      ->{ 1 }.closure?
      ").to_b.should be_false
  end

  it "does closure? false" do
    run("
      a = 1
      ->{ a }.closure?
      ").to_b.should be_true
  end

  it "does pointer" do
    address = run("
      ->{}.pointer.address
      ").to_i
    (address > 0).should be_true
  end

  it "does new on fun type" do
    run("
      alias F = Int32 -> Int32

      a = 2
      f = F.new { |x| x + a }
      f.call(1)
      ").to_i.should eq(3)
  end

  it "allows invoking a function with a subtype" do
    run(%(
      class Foo
        def x
          1
        end
      end

      class Bar < Foo
        def x
          2
        end
      end

      f = ->(foo : Foo) { foo.x }
      f.call Bar.new
      )).to_i.should eq(2)
  end

  it "allows invoking a function with a subtype when defined as block spec" do
    run(%(
      class Foo
        def x
          1
        end
      end

      class Bar < Foo
        def x
          2
        end
      end

      def func(&block : Foo -> U)
        block
      end

      f = func { |foo| foo.x }
      f.call Bar.new
      )).to_i.should eq(2)
  end

  it "allows redefining fun" do
    run(%(
      fun foo : Int32
        1
      end

      fun foo : Int32
        2
      end

      foo
      )).to_i.should eq(2)
  end
end
