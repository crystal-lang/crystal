require "../../spec_helper"

describe "Code gen: generic class type" do
  it "codegens inherited generic class instance var" do
    run(%(
      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x + 1
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new(1).x
      )).to_i.should eq(2)
  end

  it "instantiates generic class with default argument in initialize (#394)" do
    run(%(
      class Foo(T)
        def initialize(@x = 1)
        end

        def x
          @x
        end
      end

      Foo(Int32).new.x + 1
      )).to_i.should eq(2)
  end

  it "allows initializing instance variable (#665)" do
    run(%(
      class SomeType(T)
        @x = 1

        def x
          @x
        end
      end

      SomeType(Char).new.x
      )).to_i.should eq(1)
  end

  it "allows initializing instance variable in inherited generic type" do
    run(%(
      class Foo(T)
        @x = 1

        def x
          @x
        end
      end

      class Bar(T) < Foo(T)
        @y = 2
      end

      Bar(Char).new.x
      )).to_i.should eq(1)
  end

  it "declares instance var with virtual T (#1675)" do
    run(%(
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
      end

      class Generic(T)
        def initialize
          @value = uninitialized T
        end

        def value=(@value)
        end

        def value
          @value
        end
      end

      generic = Generic(Foo).new
      generic.value = Foo.new
      generic.value.foo
      )).to_i.should eq(1)
  end

  it "codegens statis array size after instantiating" do
    run(%(
      struct StaticArray(T, N)
        def size
          N
        end
      end

      alias Foo = Int32[3]

      x = uninitialized Int32[3]
      x.size
      )).to_i.should eq(3)
  end

  it "inherited instance var initialize from generic to concrete (#2128)" do
    run(%(
      class Foo(T)
        @x = 42

        def x
          @x
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.x
      )).to_i.should eq(42)
  end

  it "inherited instance var initialize from generic to generic to concrete (#2128)" do
    run(%(
      class Foo(T)
        @x = 10

        def x
          @x
        end
      end

      class Bar(T) < Foo(T)
        @y = 32

        def y
          @y
        end
      end

      class Baz < Bar(Int32)
      end

      baz = Baz.new
      baz.x + baz.y
      )).to_i.should eq(42)
  end

  it "invokes super in generic class (#2354)" do
    run(%(
      $x = 1

      class Foo
        def foo
          $x = 2
        end
      end

      class Bar(T) < Foo
        def foo
          super
        end
      end

      b = Bar(Int32).new
      b.foo

      $x
      )).to_i.should eq(2)
  end

  it "uses big integer as generic type argument (#2353)" do
    run(%(
      require "prelude"

      MIN_RANGE = -2374623294237463578
      MAX_RANGE = -MIN_RANGE

      class Hello(T)
        def self.t
          T
        end
      end

      Hello(MAX_RANGE).t
      )).to_u64.should eq(2374623294237463578)
  end
end
