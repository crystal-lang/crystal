require "../../spec_helper"

describe "Type inference: module" do
  it "includes but not a module" do
    assert_error "class Foo; end; class Bar; include Foo; end",
      "Foo is not a module"
  end

  it "includes module in a class" do
    assert_type("module Foo; def foo; 1; end; end; class Bar; include Foo; end; Bar.new.foo") { int32 }
  end

  it "includes module in a module" do
    assert_type("
      module A
        def foo
          1
        end
      end

      module B
        include A
      end

      class X
        include B
      end

      X.new.foo
      ") { int32 }
  end

  it "finds in module when included" do
    assert_type("
      module A
        class B
          def foo; 1; end
        end
      end

      include A

      B.new.foo
    ") { int32 }
  end

  it "includes generic module with type" do
    assert_type("
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar
        include Foo(Int)
      end

      Bar.new.foo(1)
      ") { int32 }
  end

  it "includes generic module and errors in call" do
    assert_error "
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar
        include Foo(Int)
      end

      Bar.new.foo(1.5)
      ",
      "no overload matches"
  end

  it "includes module but not generic" do
    assert_error "
      module Foo
      end

      class Bar
        include Foo(Int)
      end
      ",
      "Foo is not a generic module"
  end

  it "includes module but wrong number of arguments" do
    assert_error "
      module Foo(T, U)
      end

      class Bar
        include Foo(Int)
      end
      ",
      "wrong number of type vars for Foo(T, U) (given 1, expected 2)"
  end

  it "includes generic module but wrong number of arguments 2" do
    assert_error "
      module Foo(T)
      end

      class Bar
        include Foo
      end
      ",
      "Foo(T) is a generic module"
  end

  it "includes generic module explicitly" do
    assert_type("
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(U)
        include Foo(U)
      end

      Bar(Int32).new.foo(1)
      ") { int32 }
  end

  it "includes generic module explicitly and errors" do
    assert_error "
      module Foo(T)
        def foo(x : T)
          x
        end
      end

      class Bar(U)
        include Foo(U)
      end

      Bar(Int32).new.foo(1.5)
      ",
      "no overload matches"
  end

  it "reports can't use instance variables inside module" do
    assert_error "def foo; @a = 1; end; foo",
      "can't use instance variables at the top level"
  end

  it "works with int including enumerable" do
    assert_type("
      require \"prelude\"

      struct Int32
        include Enumerable(Int32)

        def each
          yield self
          yield self + 2
        end
      end

      1.map { |x| x * 0.5 }
      ") { array_of(float64) }
  end

  it "works with range and map" do
    assert_type("
      require \"prelude\"
      (1..3).map { |x| x * 0.5 }
      ") { array_of(float64) }
  end

  it "declares module automatically if not previously declared when declaring a class" do
    assert_type("
      class Foo::Bar
      end
      Foo
      ") {
      foo = types["Foo"]
      foo.module?.should be_true
      foo.metaclass
    }
  end

  it "declares module automatically if not previously declared when declaring a module" do
    assert_type("
      module Foo::Bar
      end
      Foo
      ") {
      foo = types["Foo"]
      foo.module?.should be_true
      foo.metaclass
    }
  end

  it "includes generic module with another generic type" do
    assert_type("
      module Foo(T)
        def foo
          T
        end
      end

      class Baz(X)
      end

      class Bar(U)
        include Foo(Baz(U))
      end

      Bar(Int32).new.foo
      ") {
      baz = types["Baz"] as GenericClassType
      baz.instantiate([int32] of ASTNode | Type).metaclass
    }
  end

  it "includes generic module with self" do
    assert_type("
      module Foo(T)
        def foo
          T
        end
      end

      class Baz(X)
      end

      class Bar(U)
        include Foo(self)
      end

      Bar(Int32).new.foo
      ") {
      bar = types["Bar"] as GenericClassType
      bar.instantiate([int32] of ASTNode | Type).metaclass
    }
  end

  it "includes module but can't access metaclass methods" do
    assert_error "
      module Foo
        def self.foo
          1
        end
      end

      class Bar
        include Foo
      end

      Bar.foo
      ", "undefined method 'foo'"
  end

  it "extends a module" do
    assert_type("
      module Foo
        def foo
          1
        end
      end

      class Bar
        extend Foo
      end

      Bar.foo
      ") { int32 }
  end

  it "extends self" do
    assert_type("
      module Foo
        extend self

        def foo
          1
        end
      end

      Foo.foo
      ") { int32 }
  end

  it "gives error when including self" do
    assert_error "
      module Foo
        include self
      end
      ", "cyclic include detected"
  end

  pending "gives error with cyclic include" do
    assert_error "
      module Foo
      end

      module Bar
        include Foo
      end

      module Foo
        include Bar
      end
      ", "cyclic include detected"
  end

  it "finds types close to included module" do
    assert_type("
      module Foo
        class T
        end

        def foo
          T
        end
      end

      class Bar
        class T
        end

        include Foo
      end

      Bar.new.foo
      ") { types["Foo"].types["T"].metaclass }
  end

  it "finds nested type inside method in block inside module" do
    assert_type("
      def foo
        yield
      end

      module Foo
        class Bar; end

        $x = foo { Bar }
      end

      $x
      ") { types["Foo"].types["Bar"].metaclass }
  end

  it "finds class method in block" do
    assert_type("
      def foo
        yield
      end

      module Foo
        def self.bar
          1
        end

        $x = foo { bar }
      end

      $x
      ") { int32 }
  end

  it "types pointer of module" do
    assert_type("
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo.new
      p.value
      ") { types["Moo"] }
  end

  it "types pointer of module with method" do
    assert_type("
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo.new
      p.value.foo
      ") { int32 }
  end

  it "types pointer of module with method with two including types" do
    assert_type("
      module Moo
      end

      class Foo
        include Moo

        def foo
          1
        end
      end

      class Bar
        include Moo

        def foo
          'a'
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo.new
      p.value = Bar.new
      p.value.foo
      ") { union_of(int32, char) }
  end

  it "types pointer of module with generic type" do
    assert_type("
      module Moo
      end

      class Foo(T)
        include Moo

        def foo
          1
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo(Int32).new
      p.value.foo
      ") { int32 }
  end

  it "types pointer of module with generic type" do
    assert_type("
      module Moo
      end

      class Bar
        def self.boo
          1
        end
      end

      class Baz
        def self.boo
          'a'
        end
      end

      class Foo(T)
        include Moo

        def foo
          T.boo
        end
      end

      p = Pointer(Moo).malloc(1_u64)
      p.value = Foo(Bar).new
      x = p.value.foo

      p.value = Foo(Baz).new

      x
      ") { union_of(int32, char) }
  end

  it "allows overloading with included generic module" do
    assert_type(%(
      module Foo(T)
        def foo(x : T)
          bar(x)
        end
      end

      class Bar
        include Foo(Int32)
        include Foo(String)

        def bar(x : Int32)
          1
        end

        def bar(x : String)
          "a"
        end
      end

      Bar.new.foo(1 || "hello")
      )) { union_of(int32, string) }
  end

  it "finds constant in generic module included in another module" do
    assert_type(%(
      module Foo(T)
        def foo
          T
        end
      end

      module Bar(T)
        include Foo(T)
      end

      class Baz
        include Bar(Int32)
      end

      Baz.new.foo
      )) { int32.metaclass }
  end

  it "calls super on included generic module" do
    assert_type(%(
      module Foo(T)
        def foo
          1
        end
      end

      class Bar
        include Foo(Int32)

        def foo
          super
        end
      end

      Bar.new.foo
      )) { int32 }
  end

  it "calls super on included generic module and finds type var" do
    assert_type(%(
      module Foo(T)
        def foo
          T
        end
      end

      class Bar(T)
        include Foo(T)

        def foo
          super
        end
      end

      Bar(Int32).new.foo
      )) { int32.metaclass }
  end

  it "calls super on included generic module and finds type var (2)" do
    assert_type(%(
      module Foo(T)
        def foo
          T
        end
      end

      module Bar(T)
        include Foo(T)

        def foo
          super
        end
      end

      class Baz(T)
        include Bar(T)
      end

      Baz(Int32).new.foo
      )) { int32.metaclass }
  end

  it "types union of module and class that includes it" do
    assert_type(%(
      module Moo
        def self.foo
          1
        end
      end

      class Bar
        include Moo

        def self.foo
          2
        end
      end

      Bar || Moo
      )) { union_of(types["Bar"].metaclass, types["Moo"].metaclass) }
  end

  it "works ok in a case where a typed-def type has un underlying type that has an included generic module (bug)" do
    assert_type(%(
      lib LibC
        type X = Void*
        fun x : X
      end

      module Mod(T)
        def bar(other : T)
          1
        end
      end

      struct Pointer
        include Mod(self)

        def foo
          address
        end
      end

      LibC.x.foo

      p = Pointer(Void).malloc(1_u64)
      p.bar(p)
      )) { int32 }
  end

  it "finds inner class from inherited one (#476)" do
    assert_type(%(
      class A
        class B
          class C
          end
        end
      end

      class D < A
      end

      D::B::C
      )) { types["A"].types["B"].types["C"].metaclass }
  end

  it "correctly types type var in included module, with a restriction with a free var (bug)" do
    assert_type(%(
      module Moo(T)
      end

      class Foo(T)
        include Moo(T)

        def foo(x : Moo(U))
          T
        end
      end

      Foo(Int32).new.foo(Foo(Char).new)
      )) { int32.metaclass }
  end

  it "types proc of module after type changes" do
    assert_type(%(
      module Moo
      end

      class Foo(T)
        include Moo

        def foo
          3
        end
      end

      z = ->(x : Moo) { x.foo }
      z.call(Foo(Int32).new)
      )) { int32 }
  end

  it "types proc of module with inherited generic class" do
    assert_type(%(
      module Moo
      end

      class Foo(T)
        include Moo
      end

      class Bar(T) < Foo(T)
        def foo
          'a'
        end
      end

      z = ->(x : Moo) { x.foo }
      z.call(Bar(Int32).new)
      )) { char }
  end

  it "errors if declares module inside if" do
    assert_error %(
      if 1 == 2
        module Foo; end
      end
      ),
      "can't declare module dynamically"
  end

  it "uses :Module name for modules in errors" do
    assert_error %(
      module A; end

      A.new
      ),
      "undefined method 'new' for A:Module"
  end

  it "uses type declaration inside module" do
    assert_type(%(
      module Moo
        @x : Int32

        def x
          @x
        end
      end

      class Foo
        include Moo

        def initialize
          @x = 1
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "uses type declaration inside module and gives error" do
    assert_error %(
      module Moo
        @x : Int32

        def moo
          @x = false
        end
      end

      class Foo
        include Moo

        def initialize
          @x = 1
        end
      end

      Foo.new.moo
      ),
      "instance variable '@x' of Foo must be Int32"
  end

  it "uses type declaration inside module, recursive, and gives error" do
    assert_error %(
      module Moo
        @x : Int32

        def moo
          @x = false
        end
      end

      module Moo2
        include Moo
      end

      class Foo
        include Moo2

        def initialize
          @x = 1
        end
      end

      Foo.new.moo
      ),
      "instance variable '@x' of Foo must be Int32"
  end

  it "initializes variable in module" do
    assert_type(%(
      module Moo
        @x = 1

        def x
          @x
        end
      end

      class Foo
        include Moo
      end

      Foo.new.x
      )) { int32 }
  end

  it "initializes variable in module, recursive" do
    assert_type(%(
      module Moo
        @x = 1

        def x
          @x
        end
      end

      module Moo2
        include Moo
      end

      class Foo
        include Moo2
      end

      Foo.new.x
      )) { int32 }
  end

  it "inherits instance var type annotation from generic to concrete" do
    assert_type(%(
      module Foo(T)
        @x : Int32?

        def x
          @x
        end
      end

      class Bar
        include Foo(Int32)
      end

      Bar.new.x
      )) { nilable int32 }
  end

  it "inherits instance var type annotation from generic to concrete with T" do
    assert_type(%(
      module Foo(T)
        @x : T?

        def x
          @x
        end
      end

      class Bar
        include Foo(Int32)
      end

      Bar.new.x
      )) { nilable int32 }
  end

  it "inherits instance var type annotation from generic to generic to concrete" do
    assert_type(%(
      module Foo(T)
        @x : Int32?

        def x
          @x
        end
      end

      module Bar(T)
        include Foo(T)
      end

      class Baz
        include Bar(Int32)
      end

      Baz.new.x
      )) { nilable int32 }
  end
end
