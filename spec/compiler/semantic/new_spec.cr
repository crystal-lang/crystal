require "../../spec_helper"

describe "Semantic: new" do
  it "doesn't incorrectly redefines new for generic class" do
    assert_type(%(
      class Foo(T)
        def self.new
          1
        end
      end

      Foo(Int32).new
      )) { int32 }
  end

  it "evaluates initialize default value at the instance scope (1) (#731)" do
    assert_type(%(
      class Foo
        def initialize(@x = self)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { types["Foo"] }
  end

  it "evaluates initialize default value at the instance scope (2) (#731)" do
    assert_type(%(
      class Foo
        def initialize(@x = self, @y = 'a')
        end

        def y
          @y
        end
      end

      Foo.new(y: 'b').y
      )) { char }
  end

  it "evaluates initialize default value at the instance scope (3) (#731)" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize(@x = bar)
          yield 1, 2
        end

        def x
          @x
        end

        def bar
          1
        end
      end

      foo = Foo.new do |x, y|
      end
      foo.x
      )) { int32 }
  end

  it "evaluates initialize default value at the instance scope (4) (#731)" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize(@x = bar, &@block : ->)
        end

        def x
          @x
        end

        def bar
          1
        end
      end

      foo = Foo.new do
      end
      foo.x
      )) { int32 }
  end

  it "evaluates initialize default value at the instance scope (5) (#731)" do
    assert_type(%(
      class Foo(R)
        @x : Int32

        def initialize(@x = bar, &@block : -> R)
        end

        def bar
          10
        end

        def r
          @block.call
        end
      end

      Foo.new { 1 }.r
      )) { int32 }
  end

  it "evaluates initialize default value at the instance scope (6) (#731)" do
    assert_type(%(
      class Foo(R)
        @x : Int32

        def initialize(@x = bar, &@block : -> R)
        end

        def bar
          10
        end

        def r
          @block.call
        end
      end

      Foo(Int32).new { 1 }.r
      )) { int32 }
  end

  it "errors if using self call in default argument (1)" do
    assert_error %(
      class My
        @name : String
        @caps : String

        def initialize(@name, caps = self.name)
          x = caps
          @caps = x
        end

        def name
          @name
        end
      end

      My.new("foo")
      ),
      "instance variable '@caps' of My was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported."
  end

  it "errors if using self call in default argument (2)" do
    assert_error %(
      class My
        @name : String
        @caps : String

        def initialize(@name, caps = self.name)
          @caps = caps
        end

        def name
          @name
        end
      end

      My.new("foo")
      ),
      "instance variable '@caps' of My was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported."
  end

  it "errors if using self call in default argument (3)" do
    assert_error %(
      class My
        @name : String
        @caps : String

        def initialize(@name, @caps = self.name)
        end

        def name
          @name
        end
      end

      My.new("foo")
      ),
      "instance variable '@caps' of My was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported."
  end

  it "inherits initialize and new methods if doesn't define new (#3238)" do
    assert_type(%(
      class Foo(T)
        def initialize(x : Int32)
        end

        def self.new(x : Char)
          new(1)
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new('a')
      )) { types["Bar"] }
  end

  it "doesn't have default new for inherited class from generic type" do
    assert_error %(
      class Foo(T)
        def initialize(x : Int32)
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new
      ),
      "wrong number of arguments for 'Bar.new' (given 0, expected 1)"
  end
end
