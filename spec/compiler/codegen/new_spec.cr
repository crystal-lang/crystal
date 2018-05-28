require "../../spec_helper"

describe "Code gen: new" do
  it "codegens instance method with allocate" do
    run(%(
      class Foo
        def coco
          1
        end
      end

      Foo.allocate.coco
      )).to_i.should eq(1)
  end

  it "codegens instance method with new and instance var" do
    run(%(
      class Foo
        def initialize
          @coco = 2
        end

        def coco
          @coco = 1
          @coco
        end
      end

      f = Foo.new
      f.coco
      )).to_i.should eq(1)
  end

  it "codegens instance method with new" do
    run(%(
      class Foo
        def coco
          1
        end
      end

      Foo.new.coco
      )).to_i.should eq(1)
  end

  it "can create Reference" do
    run(%(
      Reference.new.object_id == 0
      )).to_b.should be_false
  end

  it "inherits initialize" do
    run(%(
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar < Foo
      end

      Bar.new(42).x
      )).to_i.should eq(42)
  end

  it "inherits initialize for generic type" do
    run(%(
      class Foo(T)
        def initialize(@x : Int32)
        end
      end

      class Bar(T) < Foo(T)
        def x
          @x
        end
      end

      Bar(Int32).new(42).x
      )).to_i.should eq(42)
  end

  it "overloads new and initialize, 1 (#2489)" do
    run(%(
      class String
        def size
          10
        end
      end

      class Foo
        def initialize(@foo : Int32)
        end

        def self.new(bar) : self
          new bar.size
        end

        def self.new : self
          new "foo"
        end

        def foo
          @foo
        end
      end

      Foo.new.foo
      )).to_i.should eq(10)
  end

  it "overloads new and initialize, 2 (#2489)" do
    run(%(
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      class Foo
        def initialize(@foo : Int32)
        end
      end

      class Bar < Foo
        def self.new(foo : Int32) : self
          Global.x = foo + 1
          super
        end
      end

      Bar.new(5)

      Global.x
      )).to_i.should eq(6)
  end

  it "overloads new and initialize, 3 (#2489)" do
    run(%(
      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      class Foo
        def initialize(@foo : Int32)
        end

        def self.new(foo : Int32) : self
          Global.x = foo + 1
          previous_def
        end
      end

      Foo.new(5)

      Global.x
      )).to_i.should eq(6)
  end

  it "defines new for module" do
    run(%(
      module Moo
        @x : Int32

        def initialize(x : Int32)
          @x = x + 1
        end

        def x
          @x
        end
      end

      class Foo
        include Moo
      end

      Foo.new(41).x
      )).to_i.should eq(42)
  end

  it "finds super in deep hierarchy" do
    run(%(
      class Foo
        def initialize(@x : Int32)
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      class Qux < Baz
        def initialize
          super(42)
        end

        def x
          @x
        end
      end

      Qux.new.x
      )).to_i.should eq(42)
  end

  it "finds new in superclass if no initialize is defined (1)" do
    run(%(
      class Foo
        def self.new
          42
        end
      end

      class Bar < Foo
      end

      Bar.new
      )).to_i.should eq(42)
  end

  it "finds new in superclass if no initialize is defined (2)" do
    run(%(
      class Foo
        def self.new
          42
        end
      end

      class Bar < Foo
        def self.new(x)
          x
        end
      end

      Bar.new
      )).to_i.should eq(42)
  end

  it "finds new in superclass for Enum" do
    run(%(
      struct Enum
        def self.new(x : String)
          new(1)
        end
      end

      enum Color
        Red
        Green
        Blue
      end

      color = Color.new("foo")
      color.value
      )).to_i.should eq(1)
  end

  it "can create Tuple with Tuple.new" do
    run(%(
      require "prelude"

      Tuple.new.size
      )).to_i.should eq(0)
  end

  it "evaluates initialize default value at the instance scope (1) (#731)" do
    run(%(
      class Foo
        @x : Int32

        def initialize(@x = bar)
        end

        def x
          @x
        end

        def bar
          42
        end
      end

      Foo.new.x
      )).to_i.should eq(42)
  end

  it "evaluates initialize default value at the instance scope (2) (#731)" do
    run(%(
      class Foo
        @x : Int32

        def initialize(@x = bar, @y = 2)
        end

        def x
          @x
        end

        def y
          @y
        end

        def bar
          20
        end
      end

      foo = Foo.new(y: 22)
      foo.x + foo.y
      )).to_i.should eq(42)
  end

  it "evaluates initialize default value at the instance scope (3) (#731)" do
    run(%(
      class Foo
        @x : Int32

        def initialize(@x = bar)
          yield 10, 12
        end

        def x
          @x
        end

        def bar
          20
        end
      end

      total = 0
      foo = Foo.new do |a, b|
        total += a
        total += b
      end
      total += foo.x
      total
      )).to_i.should eq(42)
  end

  it "evaluates initialize default value at the instance scope (4) (#731)" do
    run(%(
      class Foo
        @x : Int32

        def initialize(@x = bar, &@block : -> Int32)
        end

        def x
          @x
        end

        def bar
          22
        end

        def block
          @block
        end
      end

      foo = Foo.new do
        20
      end
      foo.x + foo.block.call
      )).to_i.should eq(42)
  end
end
