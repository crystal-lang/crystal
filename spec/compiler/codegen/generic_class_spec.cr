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

  it "creates pointer of unspecified generic type" do
    run(%(
      struct Int32
        def to_i
          self
        end
      end

      struct Char
        def to_i
          ord
        end
      end

      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x
        end
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Foo.new(1)
      p.value = Foo.new('a')
      p.value.x.to_i
      )).to_i.should eq('a'.ord)
  end

  it "creates pointer of unspecified generic type with inherited class" do
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

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new(1)
      p.value.x
      )).to_i.should eq(2)
  end

  it "creates pointer of unspecified generic type with inherited class (2)" do
    run(%(
      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x + 1
        end
      end

      class Bar(T) < Foo(T)
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new(1)
      p.value.x
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
end
