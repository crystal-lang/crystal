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
      "wrong number of type vars for Foo(T) (given 2, expected 1)"
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

  it "creates pointer of generic type and uses it" do
    assert_type(%(
      abstract class Foo(T)
      end

      class Bar < Foo(Int32)
        def foo
          1
        end
      end

      ptr = Pointer(Foo(Int32)).malloc(1_u64)
      ptr.value = Bar.new
      ptr.value.foo
      )) { int32 }
  end

  it "creates pointer of generic type and uses it (2)" do
    assert_type(%(
      abstract class Foo(T)
      end

      class Bar(T) < Foo(T)
        def foo
          1
        end
      end

      ptr = Pointer(Foo(Int32)).malloc(1_u64)
      ptr.value = Bar(Int32).new
      ptr.value.foo
      )) { int32 }
  end

  it "errors if inheriting generic type and not specifying type vars (#460)" do
    assert_error %(
      class Foo(T)
      end

      class Bar < Foo
      end
      ),
      "wrong number of type vars for Foo(T) (given 0, expected 1)"
  end

  %w(Object Value Reference Number Int Float Struct Class Proc Tuple Enum StaticArray Pointer).each do |type|
    it "errors if using #{type} in a generic type" do
      assert_error %(
        Pointer(#{type})
        ),
        "as generic type argument yet, use a more specific type"
    end
  end

  it "errors if using Number | String in a generic type" do
    assert_error %(
      Pointer(Number | String)
      ),
      "can't use Number in unions yet, use a more specific type"
  end

  it "errors if using Number in alias" do
    assert_error %(
      alias T = Number | String
      T
      ),
      "can't use Number in unions yet, use a more specific type"
  end

  it "errors if using Number in recursive alias" do
    assert_error %(
      alias T = Number | Pointer(T)
      T
      ),
      "can't use Number in unions yet, use a more specific type"
  end

  it "finds generic type argument from method with default value" do
    assert_type(%(
      module It(T)
        def foo(x = 0)
          T
        end
      end

      class Foo(B)
        include It(B)
      end

      Foo(Int32).new.foo
      )) { int32.metaclass }
  end

  it "allows initializing instance variable (#665)" do
    assert_type(%(
      class SomeType(T)
        @x = 0

        def x
          @x
        end
      end

      SomeType(Char).new.x
      )) { int32 }
  end

  it "allows initializing instance variable in inherited generic type" do
    assert_type(%(
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
      )) { int32 }
  end

  it "calls super on generic type when superclass has no initialize (#933)" do
    assert_type(%(
      class Foo(T)
      end

      class Bar(T) < Foo(T)
          def initialize()
              super()
          end
      end

      Bar(Float32).new
    )) { (types["Bar"] as GenericClassType).instantiate([float32] of TypeVar) }
  end

  it "initializes instance variable of generic type using type var (#961)" do
    assert_type(%(
      class Bar(T)
      end

      class Foo(T)
        @bar = Bar(T).new

        def bar
          @bar
        end
      end

      Foo(Int32).new.bar
      )) { (types["Bar"] as GenericClassType).instantiate([int32] of TypeVar) }
  end

  it "errors if passing integer literal to Proc as generic argument (#1120)" do
    assert_error %(
      Proc(32)
      ),
      "argument to Proc must be a type, not 32"
  end

  it "errors if passing integer literal to Tuple as generic argument (#1120)" do
    assert_error %(
      Tuple(32)
      ),
      "argument to Tuple must be a type, not 32"
  end

  it "disallow using a non-instantiated generic type as a generic type argument" do
    assert_error %(
      class Foo(T)
      end

      class Bar(T)
      end

      Bar(Foo)
      ),
      "use a more specific type"
  end

  it "disallow using a non-instantiated module type as a generic type argument" do
    assert_error %(
      module Moo(T)
      end

      class Bar(T)
      end

      Bar(Moo)
      ),
      "use a more specific type"
  end

  it "errors on too nested generic instance" do
    assert_error %(
      class Foo(T)
      end

      def foo
        Foo(typeof(foo)).new
      end

      foo
      ),
      "generic type too nested"
  end

  it "errors on too nested generic instance, with union type" do
    assert_error %(
      class Foo(T)
      end

      def foo
        1 || Foo(typeof(foo)).new
      end

      foo
      ),
      "generic type too nested"
  end

  it "errors on generic type too nested (#2257)" do
    assert_error %(
      class Foo(T)
      end

      class Bar
        def initialize(@value)
        end

        def value
          @value
        end
      end

      foo = Foo(typeof(Bar.new(nil).value))
      Bar.new(foo)
      ),
      "generic type too nested"
  end

  it "errors on too nested tuple instance" do
    assert_error %(
      def foo
        {typeof(foo)}
      end

      foo
      ),
      "tuple type too nested"
  end

  it "gives helpful error message when generic type var is missing (#1526)" do
    assert_error %(
      class Foo(T)
        def initialize(x)
        end
      end

      Foo.new(1)
      ),
      "can't infer the type parameter T for the generic class Foo(T). Please provide it explicitly"
  end

  it "gives helpful error message when generic type var is missing in block spec (#1526)" do
    assert_error %(
      class Foo(T)
        def initialize(&block : T -> )
          block
        end
      end

      Foo.new { |x| }
      ),
      "can't infer the type parameter T for the generic class Foo(T). Please provide it explicitly"
  end

  it "can define instance var forward declared (#962)" do
    assert_type(%(
      class ClsA
        @c : ClsB(Int32)

        def initialize
          @c = ClsB(Int32).new
        end

        def c
          @c
        end
      end

      class ClsB(T)
        @pos = 0i64

        def pos
          @pos
        end
      end

      fooA = ClsA.new
      fooA.c.pos
      )) { int64 }
  end

  it "class doesn't conflict with generic type arg" do
    assert_type(%(
      class Foo(X)
        def initialize(b : X)
        end

        def x
          1
        end
      end

      class Bar(Y)
      end

      class X
      end

      Foo.new(Bar(Int32).new).x
      )) { int32 }
  end

  it "inherits instance var type annotation from generic to concrete" do
    assert_type(%(
      class Foo(T)
        @x : Int32?

        def x
          @x
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.x
      )) { nilable int32 }
  end

  it "inherits instance var type annotation from generic to concrete with T" do
    assert_type(%(
      class Foo(T)
        @x : T?

        def x
          @x
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.x
      )) { nilable int32 }
  end

  it "inherits instance var type annotation from generic to generic to concrete" do
    assert_type(%(
      class Foo(T)
        @x : Int32?

        def x
          @x
        end
      end

      class Bar(T) < Foo(T)
      end

      class Baz < Bar(Int32)
      end

      Baz.new.x
      )) { nilable int32 }
  end
end
