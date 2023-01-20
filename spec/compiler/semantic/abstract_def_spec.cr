require "../../spec_helper"

describe "Semantic: abstract def" do
  it "errors if using abstract def on subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Foo
      end

      (Bar.new || Baz.new).foo
      ), "abstract `def Foo#foo()` must be implemented by Baz"
  end

  it "works on abstract method on abstract class" do
    assert_type %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Foo
        def foo
          2
        end
      end

      b = Bar.new || Baz.new
      b.foo
      ) { int32 }
  end

  it "works on abstract def on sub-subclass" do
    assert_type(%(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          1
        end
      end

      class Baz < Bar
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new
      p.value = Baz.new
      p.value.foo
      ), inject_primitives: true) { int32 }
  end

  it "errors if using abstract def on subclass that also defines it as abstract" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      abstract class Bar < Foo
        abstract def foo
      end

      class Baz < Bar
      end
      ), "abstract `def Foo#foo()` must be implemented by Baz"
  end

  it "gives correct error when no overload matches, when an abstract method is implemented (#1406)" do
    assert_error %(
      abstract class Foo
        abstract def foo(x : Int32)
      end

      class Bar < Foo
        def foo(x : Int32)
          1
        end
      end

      Bar.new.foo(1 || 'a')
      ),
      "expected argument #1 to 'Bar#foo' to be Int32, not (Char | Int32)"
  end

  it "errors if using abstract def on non-abstract class" do
    assert_error %(
      class Foo
        abstract def foo
      end
      ),
      "can't define abstract def on non-abstract class"
  end

  it "errors if using abstract def on metaclass" do
    assert_error %(
      class Foo
        abstract def self.foo
      end
      ),
      "can't define abstract def on metaclass"
  end

  it "errors if abstract method is not implemented by subclass" do
    exc = assert_error <<-CRYSTAL,
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
      end
      CRYSTAL
      "abstract `def Foo#foo()` must be implemented by Bar"
    exc.line_number.should eq 5
    exc.column_number.should eq 1
  end

  it "errors if abstract method with arguments is not implemented by subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo(x, y)
      end

      class Bar < Foo
      end
      ),
      "abstract `def Foo#foo(x, y)` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass (wrong number of arguments)" do
    assert_error %(
      abstract class Foo
        abstract def foo(x)
      end

      class Bar < Foo
        def foo(x, y)
        end
      end
      ),
      "abstract `def Foo#foo(x)` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass (wrong type)" do
    assert_error %(
      abstract class Foo
        abstract def foo(x, y : Int32)
      end

      class Bar < Foo
        def foo(x, y : Float64)
        end
      end
      ),
      "abstract `def Foo#foo(x, y : Int32)` must be implemented by Bar"
  end

  it "errors if abstract method with arguments is not implemented by subclass (block difference)" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
          yield
        end
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Bar"
  end

  it "doesn't error if abstract method is implemented by subclass" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
        end
      end
      CRYSTAL
  end

  it "doesn't error if abstract method with args is implemented by subclass" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(x, y)
      end

      class Bar < Foo
        def foo(x, y)
        end
      end
      CRYSTAL
  end

  it "doesn't error if abstract method with args is implemented by subclass (restriction -> no restriction)" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(x, y : Int32)
      end

      class Bar < Foo
        def foo(x, y)
        end
      end
      CRYSTAL
  end

  it "doesn't error if abstract method with args is implemented by subclass (don't check subclasses)" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo
        end
      end

      class Baz < Bar
      end
      CRYSTAL
  end

  it "errors if abstract method of private type is not implemented by subclass" do
    assert_error <<-CRYSTAL, "abstract `def Foo#foo()` must be implemented by Bar"
      private abstract class Foo
        abstract def foo
      end

      class Bar < Foo
      end
      CRYSTAL
  end

  it "errors if abstract method is not implemented by subclass of subclass" do
    assert_error %(
      abstract class Foo
        abstract def foo
      end

      abstract class Bar < Foo
      end

      class Baz < Bar
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Baz"
  end

  it "doesn't error if abstract method is implemented by subclass via module inclusion" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo
      end

      module Moo
        def foo
        end
      end

      class Bar < Foo
        include Moo
      end
      CRYSTAL
  end

  it "errors if abstract method is not implemented by including class" do
    assert_error %(
      module Foo
        abstract def foo
      end

      class Bar
        include Foo
      end
      ),
      "abstract `def Foo#foo()` must be implemented by Bar"
  end

  it "doesn't error if abstract method is implemented by including class" do
    assert_no_errors <<-CRYSTAL
      module Foo
        abstract def foo
      end

      class Bar
        include Foo

        def foo
        end
      end
      CRYSTAL
  end

  it "errors if abstract method of private type is not implemented by including class" do
    assert_error <<-CRYSTAL, "abstract `def Foo#foo()` must be implemented by Bar"
      private module Foo
        abstract def foo
      end

      class Bar
        include Foo
      end
      CRYSTAL
  end

  it "doesn't error if abstract method is not implemented by including module" do
    assert_no_errors <<-CRYSTAL
      module Foo
        abstract def foo
      end

      module Bar
        include Foo
      end
      CRYSTAL
  end

  it "errors if abstract method is not implemented by subclass (nested in module)" do
    assert_error %(
      module Moo
        abstract class Foo
          abstract def foo
        end
      end

      class Bar < Moo::Foo
      end
      ),
      "abstract `def Moo::Foo#foo()` must be implemented by Bar"
  end

  it "doesn't error if abstract method with args is implemented by subclass (with one default arg)" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(x)
      end

      class Bar < Foo
        def foo(x, y = 1)
        end
      end
      CRYSTAL
  end

  it "doesn't error if implements with parent class" do
    assert_no_errors %(
      class Parent; end
      class Child < Parent; end

      abstract class Foo
        abstract def foo(x : Child)
      end

      class Bar < Foo
        def foo(x : Parent)
        end
      end
      )
  end

  it "doesn't error if implements with generic parent class instance" do
    assert_no_errors %(
      class Parent(T); end
      class Child(T) < Parent(T); end

      abstract class Foo
        abstract def foo(x : Child(Int32))
      end

      class Bar < Foo
        def foo(x : Parent(Int32))
        end
      end
      )
  end

  it "doesn't error if implements with included module" do
    assert_no_errors %(
      module Moo
      end

      module Moo2
        include Moo
      end

      abstract class Foo
        abstract def foo(x : Moo2)
      end

      class Bar < Foo
        def foo(x : Moo)
        end
      end
      )
  end

  it "doesn't error if implements with generic included module instance" do
    assert_no_errors %(
      module Moo(T)
      end

      module Moo2(T)
        include Moo(T)
      end

      abstract class Foo
        abstract def foo(x : Moo2(Int32))
      end

      class Bar < Foo
        def foo(x : Moo(Int32))
        end
      end
      )
  end

  it "doesn't error if implements with parent module" do
    assert_no_errors %(
      module Moo
      end

      module Moo2
        include Moo
      end

      class Child
        include Moo2
      end

      abstract class Foo
        abstract def foo(x : Child)
      end

      class Bar < Foo
        def foo(x : Moo)
        end
      end
      )
  end

  it "doesn't error if implements a NoReturn param" do
    assert_no_errors %(
      abstract class Foo
        abstract def foo(x : NoReturn)
      end

      class Bar < Foo
        def foo(x : Int32)
        end
      end
      )
  end

  it "finds implements in included module in disorder (#4052)" do
    assert_no_errors <<-CRYSTAL
      module B
        abstract def x
      end

      module C
        def x
          :x
        end
      end

      class A
        include C
        include B
      end
      CRYSTAL
  end

  it "errors if missing return type" do
    assert_error <<-CRYSTAL,
      abstract class Foo
        abstract def foo : Int32
      end

      class Bar < Foo
        def foo
          1
        end
      end
      CRYSTAL
      "this method overrides Foo#foo() which has an explicit return type of Int32.\n\nPlease add an explicit return type (Int32 or a subtype of it) to this method as well."
  end

  it "errors if different return type" do
    assert_error <<-CRYSTAL,
      abstract class Foo
        abstract def foo : Int32
      end

      class Bar < Foo
        struct Int32
        end

        def foo : Int32
          1
        end
      end
      CRYSTAL
      "this method must return Int32, which is the return type of the overridden method Foo#foo(), or a subtype of it, not Bar::Int32"
  end

  it "can return a more specific type" do
    assert_type(%(
      class Parent
      end

      class Child < Parent
      end


      abstract class Foo
        abstract def foo : Parent
      end

      class Bar < Foo
        def foo : Child
          Child.new
        end
      end

      Bar.new.foo
      )) { types["Child"] }
  end

  it "matches instantiated generic types" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo(T)
        abstract def foo(x : T)
      end

      abstract class Bar(U) < Foo(U)
      end

      class Baz < Bar(Int32)
        def foo(x : Int32)
        end
      end
      CRYSTAL
  end

  it "matches generic types" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo(T)
        abstract def foo(x : T)
      end

      class Bar(U) < Foo(U)
        def foo(x : U)
        end
      end
      CRYSTAL
  end

  it "matches instantiated generic module" do
    assert_no_errors <<-CRYSTAL
      module Foo(T)
        abstract def foo(x : T)
      end

      class Bar
        include Foo(Int32)

        def foo(x : Int32)
        end
      end
      CRYSTAL
  end

  it "matches generic module" do
    assert_no_errors <<-CRYSTAL
      module Foo(T)
        abstract def foo(x : T)
      end

      class Bar(U)
        include Foo(U)

        def foo(x : U)
        end
      end
      CRYSTAL
  end

  it "matches generic module (a bit more complex)" do
    assert_no_errors <<-CRYSTAL
      class Gen(T)
      end

      module Foo(T)
        abstract def foo(x : Gen(T))
      end

      class Bar
        include Foo(Int32)

        def foo(x : Gen(Int32))
        end
      end
      CRYSTAL
  end

  it "matches generic return type" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo(T)
        abstract def foo : T
      end

      class Bar < Foo(Int32)
        def foo : Int32
          1
        end
      end
      CRYSTAL
  end

  it "errors if missing a return type in subclass of generic subclass" do
    assert_error <<-CRYSTAL,
        abstract class Foo(T)
          abstract def foo : T
        end

        class Bar < Foo(Int32)
          def foo
          end
        end
      CRYSTAL
      "this method overrides Foo(T)#foo() which has an explicit return type of T.\n\nPlease add an explicit return type (Int32 or a subtype of it) to this method as well."
  end

  it "errors if can't find parent return type" do
    assert_error <<-CRYSTAL,
        abstract class Foo
          abstract def foo : Unknown
        end

        class Bar < Foo
          def foo
          end
        end
      CRYSTAL
      "can't resolve return type Unknown"
  end

  it "errors if can't find child return type" do
    assert_error <<-CRYSTAL,
        abstract class Foo
          abstract def foo : Int32
        end

        class Bar < Foo
          def foo : Unknown
          end
        end
      CRYSTAL
      "can't resolve return type Unknown"
  end

  it "implements through extend (considers original type for generic lookup) (#8096)" do
    assert_no_errors <<-CRYSTAL
      module ICallable(T)
        abstract def call(foo : T)
      end

      module Moo
        def call(foo : Int32)
        end
      end

      module Caller
        extend ICallable(Int32)
        extend Moo
      end
      CRYSTAL
  end

  it "implements through extend (considers original type for generic lookup) (2) (#8096)" do
    assert_no_errors <<-CRYSTAL
      module ICallable(T)
        abstract def call(foo : T)
      end

      module Caller
        extend ICallable(Int32)
        extend self

        def call(foo : Int32)
        end
      end
      CRYSTAL
  end

  it "can implement even if yield comes later in macro code" do
    assert_no_errors <<-CRYSTAL
      module Moo
        abstract def each(& : Int32 -> _)
      end

      class Foo
        include Moo

        def each
          yield 1

          {% if true %}
            yield 2
          {% end %}
        end
      end
      CRYSTAL
  end

  it "can implement by block signature even if yield comes later in macro code" do
    assert_no_errors <<-CRYSTAL
      module Moo
        abstract def each(& : Int32 -> _)
      end

      class Foo
        include Moo

        def each(& : Int32 -> _)
          {% if true %}
            yield 2
          {% end %}
        end
      end
      CRYSTAL
  end

  it "error shows full signature of block parameter" do
    assert_error(<<-CRYSTAL, "abstract `def Moo#each(& : (Int32 -> _))` must be implemented by Foo")
      module Moo
        abstract def each(& : Int32 -> _)
      end

      class Foo
        include Moo
      end
      CRYSTAL
  end

  it "doesn't error if implementation have default value" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(x)
      end

      class Bar < Foo
        def foo(x = 1)
        end
      end
      CRYSTAL
  end

  it "errors if implementation doesn't have default value" do
    assert_error %(
      abstract class Foo
        abstract def foo(x = 1)
      end

      class Bar < Foo
        def foo(x)
        end
      end
      ),
      "abstract `def Foo#foo(x = 1)` must be implemented by Bar"
  end

  it "errors if implementation doesn't have the same default value" do
    assert_error %(
      abstract class Foo
        abstract def foo(x = 1)
      end

      class Bar < Foo
        def foo(x = 2)
        end
      end
      ),
      "abstract `def Foo#foo(x = 1)` must be implemented by Bar"
  end

  it "errors if implementation adds type restriction" do
    assert_error %(
      abstract class Foo
        abstract def foo(x)
      end

      class Bar < Foo
        def foo(x : Int32)
        end
      end
    ), "abstract `def Foo#foo(x)` must be implemented by Bar"
  end

  it "errors if implementation doesn't have keyword arguments" do
    assert_error %(
      abstract class Foo
        abstract def foo(*, x)
      end

      class Bar < Foo
        def foo(a = 0, b = 0)
        end
      end
      ),
      "abstract `def Foo#foo(*, x)` must be implemented by Bar"
  end

  it "errors if implementation doesn't have a keyword argument" do
    assert_error %(
      abstract class Foo
        abstract def foo(*, x)
      end

      class Bar < Foo
        def foo(*, y)
        end
      end
      ),
      "abstract `def Foo#foo(*, x)` must be implemented by Bar"
  end

  it "doesn't error if implementation matches keyword argument" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(*, x)
      end

      class Bar < Foo
        def foo(*, x)
        end
      end
      CRYSTAL
  end

  it "errors if implementation doesn't match keyword argument type" do
    assert_error %(
      abstract class Foo
        abstract def foo(*, x : Int32)
      end

      class Bar < Foo
        def foo(*, x : String)
        end
      end
      ),
      "abstract `def Foo#foo(*, x : Int32)` must be implemented by Bar"
  end

  it "doesn't error if implementation have keyword arguments in different order" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(*, x : Int32, y : String)
      end

      class Bar < Foo
        def foo(*, y : String, x : Int32)
        end
      end
      CRYSTAL
  end

  it "errors if implementation has more keyword arguments" do
    assert_error %(
      abstract class Foo
        abstract def foo(*, x)
      end

      class Bar < Foo
        def foo(*, x, y)
        end
      end
      ),
      "abstract `def Foo#foo(*, x)` must be implemented by Bar"
  end

  it "doesn't error if implementation has more keyword arguments with default values" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(*, x)
      end

      class Bar < Foo
        def foo(*, x, y = 1)
        end
      end
      CRYSTAL
  end

  it "errors if implementation doesn't have a splat" do
    assert_error %(
      abstract class Foo
        abstract def foo(*args)
      end

      class Bar < Foo
        def foo(x = 1)
        end
      end
      ),
      "abstract `def Foo#foo(*args)` must be implemented by Bar"
  end

  it "errors if implementation doesn't match splat type" do
    assert_error %(
      abstract class Foo
        abstract def foo(*args : Int32)
      end

      class Bar < Foo
        def foo(*args : String)
        end
      end
      ),
      "abstract `def Foo#foo(*args : Int32)` must be implemented by Bar"
  end

  it "doesn't error with splat" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(*args)
      end

      class Bar < Foo
        def foo(*args)
        end
      end
      CRYSTAL
  end

  it "doesn't error with splat and args with default value" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(*args)
      end

      class Bar < Foo
        def foo(a = 1, *args)
        end
      end
      CRYSTAL
  end

  it "allows arguments to be collapsed into splat" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(a : Int32, b : String)
      end

      class Bar < Foo
        def foo(*args : Int32 | String)
        end
      end
      CRYSTAL
  end

  it "errors if keyword argument doesn't have the same default value" do
    assert_error %(
      abstract class Foo
        abstract def foo(*, foo = 1)
      end

      class Bar < Foo
        def foo(*, foo = 2)
        end
      end
    ), "abstract `def Foo#foo(*, foo = 1)` must be implemented by Bar"
  end

  it "allow double splat argument" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(**kargs)
      end

      class Bar < Foo
        def foo(**kargs)
        end
      end
      CRYSTAL
  end

  it "allow double splat when abstract doesn't have it" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo
      end

      class Bar < Foo
        def foo(**kargs)
        end
      end
      CRYSTAL
  end

  it "errors if implementation misses the double splat" do
    assert_error %(
      abstract class Foo
        abstract def foo(**kargs)
      end

      class Bar < Foo
        def foo
        end
      end
    ), "abstract `def Foo#foo(**kargs)` must be implemented by Bar"
  end

  it "errors if double splat type doesn't match" do
    assert_error %(
      abstract class Foo
        abstract def foo(**kargs : Int32)
      end

      class Bar < Foo
        def foo(**kargs : String)
        end
      end
    ), "abstract `def Foo#foo(**kargs : Int32)` must be implemented by Bar"
  end

  it "allow splat instead of keyword argument" do
    assert_no_errors <<-CRYSTAL
      abstract class Foo
        abstract def foo(*, foo)
      end

      class Bar < Foo
        def foo(**kargs)
        end
      end
      CRYSTAL
  end

  it "extra keyword arguments must have compatible type to double splat" do
    assert_error %(
      abstract class Foo
        abstract def foo(**kargs : String)
      end

      class Bar < Foo
        def foo(*, foo : Int32 = 0, **kargs)
        end
      end
    ), "abstract `def Foo#foo(**kargs : String)` must be implemented by Bar"
  end

  it "double splat must match keyword argument type" do
    assert_error %(
      abstract class Foo
        abstract def foo(*, foo : Int32)
      end

      class Bar < Foo
        def foo(**kargs : String)
        end
      end
    ), "abstract `def Foo#foo(*, foo : Int32)` must be implemented by Bar"
  end

  it "doesn't error if free var in arg restriction shadows another type (#10153)" do
    assert_no_errors %(
      module Foo
        abstract def foo(x : Int32, y : Array(Int32))
      end

      class Bar
        include Foo

        def foo(x : Quux, y : Array(Quux)) forall Quux
          x
        end
      end

      class Quux
      end
      )
  end

  describe "implementation is not inherited from supertype" do
    it "nongeneric class" do
      assert_error <<-CRYSTAL, "abstract `def Abstract#foo()` must be implemented by Concrete"
        class Supertype
          def foo; end
        end

        abstract class Abstract < Supertype
          abstract def foo
        end

        class Concrete < Abstract
        end
        CRYSTAL
    end

    it "generic class" do
      assert_error <<-CRYSTAL, "abstract `def Abstract(T)#foo()` must be implemented by Concrete"
        class Supertype(T)
          def foo; end
        end

        abstract class Abstract(T) < Supertype(T)
          abstract def foo
        end

        class Concrete(T) < Abstract(T)
        end
        CRYSTAL
    end

    it "nongeneric module" do
      assert_error <<-CRYSTAL, "abstract `def Abstract#size()` must be implemented by Concrete"
        module Supertype
          def size
          end
        end

        module Abstract
          include Supertype

          abstract def size
        end

        class Concrete
          include Abstract
        end
        CRYSTAL
    end

    it "generic module" do
      assert_error <<-CRYSTAL, "abstract `def Abstract(T)#size()` must be implemented by Concrete(T)"
        module Supertype(T)
          def size
          end
        end

        module Abstract(T)
          include Supertype(T)

          abstract def size
        end

        class Concrete(T)
          include Abstract(T)
        end
        CRYSTAL
    end
  end
end
