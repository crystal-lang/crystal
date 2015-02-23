require "../../spec_helper"

describe "Type inference: generic class" do
  it "errors if inheriting from generic when it is non-generic" do
    assert_error %(
      class Foo
      end

      class Bar < Foo(T)
      end
      ),
      "Foo is not a generic class, it's a class"
  end

  it "errors if inheriting from generic and incorrect number of type vars" do
    assert_error %(
      class Foo(T)
      end

      class Bar < Foo(A, B)
      end
      ),
      "wrong number of type vars for Foo(T) (2 for 1)"
  end

  it "inhertis from generic with instantiation" do
    assert_type(%(
      class Foo(T)
        def t
          T
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.t
      )) { int32.metaclass }
  end

  it "inhertis from generic with forwarding (1)" do
    assert_type(%(
      class Foo(T)
        def t
          T
        end
      end

      class Bar(U) < Foo(U)
      end

      Bar(Int32).new.t
      )) { int32.metaclass }
  end

  it "inhertis from generic with forwarding (2)" do
    assert_type(%(
      class Foo(T)
      end

      class Bar(U) < Foo(U)
        def u
          U
        end
      end

      Bar(Int32).new.u
      )) { int32.metaclass }
  end

  it "inhertis from generic with instantiation with instance var" do
    assert_type(%(
      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new(1).x
      )) { int32 }
  end

  it "inherits twice" do
    assert_type(%(
      class Foo
        def initialize
          @x = 1.5
        end

        def x
          @x
        end
      end

      class Bar(T) < Foo
        def initialize(@y : T)
          super()
        end

        def y
          @y
        end
      end

      class Baz < Bar(Int32)
        def initialize(y, @z)
          super(y)
        end

        def z
          @z
        end
      end

      baz = Baz.new(1, 'a')
      baz.y
      )) { int32 }
  end

  it "inherits non-generic to generic (1)" do
    assert_type(%(
      class Foo(T)
        def t1
          T
        end
      end

      class Bar < Foo(Int32)
      end

      class Baz(T) < Bar
      end

      baz = Baz(Float64).new
      baz.t1
      )) { int32.metaclass }
  end

  it "inherits non-generic to generic (2)" do
    assert_type(%(
      class Foo(T)
        def t1
          T
        end
      end

      class Bar < Foo(Int32)
      end

      class Baz(T) < Bar
        def t2
          T
        end
      end

      baz = Baz(Float64).new
      baz.t2
      )) { float64.metaclass }
  end

  it "defines empty initialize on inherited generic class" do
    assert_type(%(
      class Maybe(T)
      end

      class Nothing < Maybe(Int32)
        def initialize
        end
      end

      Nothing.new
      )) { types["Nothing"] }
  end

  it "restricts non-generic to generic" do
    assert_type(%(
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      def foo(x : Foo)
        x
      end

      foo Bar.new
      )) { types["Bar"] }
  end

  it "restricts non-generic to generic with free var" do
    assert_type(%(
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      def foo(x : Foo(T))
        T
      end

      foo Bar.new
      )) { int32.metaclass }
  end

  it "restricts generic to generic with free var" do
    assert_type(%(
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      def foo(x : Foo(T))
        T
      end

      foo Bar(Int32).new
      )) { int32.metaclass }
  end

  it "creates pointer of unspecified generic type (1)" do
    assert_type(%(
      class Foo(T)
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Foo(Int32).new
      p.value = Foo(Float64).new
      p.value
      )) { types["Foo"] }
  end

  it "creates pointer of unspecified generic type (2)" do
    assert_type(%(
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
      p.value.x
      )) { union_of int32, char }
  end

  it "creates pointer of unspecified generic type with inherited class" do
    assert_type(%(
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar(Int32).new
      p.value
      )) { types["Foo"] }
  end

  it "allows T::Type with T a generic type" do
    assert_type(%(
      class MyType
        class Bar
        end
      end

      class Foo(T)
        def bar
          T::Bar.new
        end
      end

      Foo(MyType).new.bar
      )) { types["MyType"].types["Bar"] }
  end

  it "error on T::Type with T a generic type that's a union" do
    assert_error %(
      class Foo(T)
        def self.bar
          T::Bar
        end
      end

      Foo(Char | String).bar
      ),
      "can't lookup type in union (Char | String)"
  end

  it "instantiates generic class with default argument in initialize (#394)" do
    assert_type(%(
      class Foo(T)
        def initialize(x = 1)
        end
      end

      Foo(Int32).new
      )) { (types["Foo"] as GenericClassType).instantiate([int32] of TypeVar) }
  end

  it "inherits class methods from generic class" do
    assert_type(%(
      class Foo(T)
        def self.foo
          1
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.foo
      )) { int32 }
  end
end
