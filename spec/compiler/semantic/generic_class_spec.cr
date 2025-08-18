require "../../spec_helper"

describe "Semantic: generic class" do
  it "errors if inheriting from generic when it is non-generic" do
    assert_error <<-CRYSTAL, "Foo is not a generic type, it's a class"
      class Foo
      end

      class Bar < Foo(T)
      end
      CRYSTAL
  end

  it "errors if inheriting from generic and incorrect number of type vars" do
    assert_error <<-CRYSTAL, "wrong number of type vars for Foo(T) (given 2, expected 1)"
      class Foo(T)
      end

      class Bar < Foo(A, B)
      end
      CRYSTAL
  end

  it "inherits from generic with instantiation" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      class Foo(T)
        def t
          T
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.t
      CRYSTAL
  end

  it "inherits from generic with forwarding (1)" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      class Foo(T)
        def t
          T
        end
      end

      class Bar(U) < Foo(U)
      end

      Bar(Int32).new.t
      CRYSTAL
  end

  it "inherits from generic with forwarding (2)" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      class Foo(T)
      end

      class Bar(U) < Foo(U)
        def u
          U
        end
      end

      Bar(Int32).new.u
      CRYSTAL
  end

  it "accesses generic type argument from superclass, def context (#10834)" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { int32.metaclass }
      class Foo(T)
      end

      class Bar(U) < Foo(U)
        def t
          T
        end
      end

      Bar(Int32).new.t
      CRYSTAL
  end

  it "accesses generic type argument from superclass, metaclass context" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { int32 }
      struct Int32
        def self.new(x : Int32)
          x
        end
      end

      class Foo(T)
      end

      class Bar(U) < Foo(U)
        @x = T.new(0)
      end

      Bar(Int32).new.@x
      CRYSTAL
  end

  it "accesses generic type argument from superclass, macro context" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { char }
      class Foo(M)
      end

      class Bar(N) < Foo(N)
        def t
          {{ M == 1 ? 'a' : "" }}
        end
      end

      Bar(1).new.t
      CRYSTAL
  end

  it "accesses generic type argument from superclass, def restriction" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { int32 }
      class Foo(T)
      end

      class Bar(U) < Foo(U)
        def foo(x : T)
          x
        end
      end

      Bar(Int32).new.foo(1)
      CRYSTAL
  end

  it "uses inherited #initialize from superclass when generic type parameters are identical" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { int32 }
      class Foo(T)
        def initialize(@value : T)
        end
      end

      class Bar(T) < Foo(T)
      end

      Bar.new(25).@value
      CRYSTAL
  end

  pending "accesses generic type argument from superclass, inherited #initialize (1) (#5243)" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { int32 }
      class Foo(T)
        def initialize(@value : T)
        end
      end

      class Bar(U) < Foo(U)
      end

      Bar.new(25).@value
      CRYSTAL
  end

  it "accesses generic type argument from superclass, inherited #initialize (2) (#5243)" do
    assert_type(<<-CRYSTAL, inject_primitives: false) { int32 }
      class Foo(T)
        def initialize(@value : T)
        end
      end

      class Bar(U) < Foo(U)
      end

      Bar(Int32).new(25).@value
      CRYSTAL
  end

  it "inherits from generic with instantiation with instance var" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "inherits twice" do
    assert_type(<<-CRYSTAL) { int32 }
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
        def initialize(y, @z : Char)
          super(y)
        end

        def z
          @z
        end
      end

      baz = Baz.new(1, 'a')
      baz.y
      CRYSTAL
  end

  it "doesn't compute generic instance var initializers in formal superclass's context (#4753)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        @foo = T.new

        def foo
          @foo
        end
      end

      class Bar(T) < Foo(T)
      end

      class Baz
        def baz
          1
        end
      end

      Bar(Baz).new.foo.baz
      CRYSTAL
  end

  it "inherits non-generic to generic (1)" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
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
      CRYSTAL
  end

  it "inherits non-generic to generic (2)" do
    assert_type(<<-CRYSTAL) { float64.metaclass }
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
      CRYSTAL
  end

  it "defines empty initialize on inherited generic class" do
    assert_type(<<-CRYSTAL) { types["Nothing"] }
      class Maybe(T)
      end

      class Nothing < Maybe(Int32)
        def initialize
        end
      end

      Nothing.new
      CRYSTAL
  end

  it "restricts non-generic to generic" do
    assert_type(<<-CRYSTAL) { types["Bar"] }
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      def foo(x : Foo)
        x
      end

      foo Bar.new
      CRYSTAL
  end

  it "restricts non-generic to generic with free var" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      class Foo(T)
      end

      class Bar < Foo(Int32)
      end

      def foo(x : Foo(T)) forall T
        T
      end

      foo Bar.new
      CRYSTAL
  end

  it "restricts generic to generic with free var" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      def foo(x : Foo(T)) forall T
        T
      end

      foo Bar(Int32).new
      CRYSTAL
  end

  it "allows T::Type with T a generic type" do
    assert_type(<<-CRYSTAL) { types["MyType"].types["Bar"] }
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
      CRYSTAL
  end

  it "error on T::Type with T a generic type that's a union" do
    assert_error <<-CRYSTAL, "undefined constant T::Bar"
      class Foo(T)
        def self.bar
          T::Bar
        end
      end

      Foo(Char | String).bar
      CRYSTAL
  end

  it "instantiates generic class with default argument in initialize (#394)" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", int32 }
      class Foo(T)
        def initialize(x = 1)
        end
      end

      Foo(Int32).new
      CRYSTAL
  end

  it "inherits class methods from generic class" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        def self.foo
          1
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.foo
      CRYSTAL
  end

  it "creates pointer of generic type and uses it" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
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
      CRYSTAL
  end

  it "creates pointer of generic type and uses it (2)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
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
      CRYSTAL
  end

  it "errors if inheriting generic type and not specifying type vars (#460)" do
    assert_error <<-CRYSTAL, "generic type arguments must be specified when inheriting Foo(T)"
      class Foo(T)
      end

      class Bar < Foo
      end
      CRYSTAL
  end

  %w(Object Value Reference Number Int Float Struct Class Proc Tuple Enum StaticArray Pointer).each do |type|
    it "errors if using #{type} in a generic type" do
      assert_error <<-CRYSTAL, "as generic type argument yet, use a more specific type"
        Pointer(#{type})
        CRYSTAL
    end
  end

  it "errors if using Number | String in a generic type" do
    assert_error <<-CRYSTAL, "can't use Number in unions yet, use a more specific type"
      Pointer(Number | String)
      CRYSTAL
  end

  it "errors if using Number in alias" do
    assert_error <<-CRYSTAL, "can't use Number in unions yet, use a more specific type"
      alias Alias = Number | String
      Alias
      CRYSTAL
  end

  it "errors if using Number in recursive alias" do
    assert_error <<-CRYSTAL, "can't use Number in unions yet, use a more specific type"
      alias Alias = Number | Pointer(Alias)
      Alias
      CRYSTAL
  end

  it "finds generic type argument from method with default value" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      module It(T)
        def foo(x = 0)
          T
        end
      end

      class Foo(B)
        include It(B)
      end

      Foo(Int32).new.foo
      CRYSTAL
  end

  it "allows initializing instance variable (#665)" do
    assert_type(<<-CRYSTAL) { int32 }
      class SomeType(T)
        @x = 0

        def x
          @x
        end
      end

      SomeType(Char).new.x
      CRYSTAL
  end

  it "allows initializing instance variable in inherited generic type" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "calls super on generic type when superclass has no initialize (#933)" do
    assert_type(<<-CRYSTAL) { generic_class "Bar", float32 }
      class Foo(T)
      end

      class Bar(T) < Foo(T)
          def initialize()
              super()
          end
      end

      Bar(Float32).new
      CRYSTAL
  end

  it "initializes instance variable of generic type using type var (#961)" do
    assert_type(<<-CRYSTAL) { generic_class "Bar", int32 }
      class Bar(T)
      end

      class Foo(T)
        @bar = Bar(T).new

        def bar
          @bar
        end
      end

      Foo(Int32).new.bar
      CRYSTAL
  end

  it "errors if passing integer literal to Proc as generic argument (#1120)" do
    assert_error <<-CRYSTAL, "argument to Proc must be a type, not 32"
      Proc(32)
      CRYSTAL
  end

  it "errors if passing integer literal to Tuple as generic argument (#1120)" do
    assert_error <<-CRYSTAL, "argument to Tuple must be a type, not 32"
      Tuple(32)
      CRYSTAL
  end

  it "errors if passing integer literal to Union as generic argument" do
    assert_error <<-CRYSTAL, "argument to Union must be a type, not 32"
      Union(32)
      CRYSTAL
  end

  it "disallow using a non-instantiated generic type as a generic type argument" do
    assert_error <<-CRYSTAL, "use a more specific type"
      class Foo(T)
      end

      class Bar(T)
      end

      Bar(Foo)
      CRYSTAL
  end

  it "disallow using a non-instantiated module type as a generic type argument" do
    assert_error <<-CRYSTAL, "use a more specific type"
      module Moo(T)
      end

      class Bar(T)
      end

      Bar(Moo)
      CRYSTAL
  end

  it "errors on too nested generic instance" do
    assert_error <<-CRYSTAL, "generic type too nested"
      class Foo(T)
      end

      def foo
        Foo(typeof(foo)).new
      end

      foo
      CRYSTAL
  end

  it "errors on too nested generic instance, with union type" do
    assert_error <<-CRYSTAL, "generic type too nested"
      class Foo(T)
      end

      def foo
        1 || Foo(typeof(foo)).new
      end

      foo
      CRYSTAL
  end

  it "errors on too nested tuple instance" do
    assert_error <<-CRYSTAL, "tuple type too nested"
      def foo
        {typeof(foo)}
      end

      foo
      CRYSTAL
  end

  it "gives helpful error message when generic type var is missing (#1526)" do
    assert_error <<-CRYSTAL, "can't infer the type parameter T for the generic class Foo(T). Please provide it explicitly"
      class Foo(T)
        def initialize(x)
        end
      end

      Foo.new(1)
      CRYSTAL
  end

  it "gives helpful error message when generic type var is missing in block spec (#1526)" do
    assert_error <<-CRYSTAL, "can't infer the type parameter T for the generic class Foo(T). Please provide it explicitly"
      class Foo(T)
        def initialize(&block : T -> )
          block
        end
      end

      Foo.new { |x| }
      CRYSTAL
  end

  it "can define instance var forward declared (#962)" do
    assert_type(<<-CRYSTAL) { int64 }
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

      foo = ClsA.new
      foo.c.pos
      CRYSTAL
  end

  it "inherits instance var type annotation from generic to concrete" do
    assert_type(<<-CRYSTAL) { nilable int32 }
      class Foo(T)
        @x : Int32?

        def x
          @x
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.x
      CRYSTAL
  end

  it "inherits instance var type annotation from generic to concrete with T" do
    assert_type(<<-CRYSTAL) { nilable int32 }
      class Foo(T)
        @x : T?

        def x
          @x
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new.x
      CRYSTAL
  end

  it "inherits instance var type annotation from generic to generic to concrete" do
    assert_type(<<-CRYSTAL) { nilable int32 }
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
      CRYSTAL
  end

  it "doesn't duplicate overload on generic class with class method (#2385)" do
    error = assert_error <<-CRYSTAL
      class Foo(T)
        def self.foo(x : Int32)
        end
      end

      Foo(String).foo(35.7)
      CRYSTAL

    error.to_s.lines.count(" - Foo(T).foo(x : Int32)").should eq(1)
  end

  # Given:
  #
  # ```
  # class Parent; end
  #
  # class Child1 < Parent; end
  #
  # class Child2 < Parent; end
  #
  # $x : Array(Parent)
  # $x = [] of Parent
  # ```
  #
  # This must not be allowed:
  #
  # ```
  # $x = [] of Child1
  # ```
  #
  # Because if the type of $x is considered Array(Parent) by the compiler,
  # this should be allowed:
  #
  # ```
  # $x << Child2.new
  # ```
  #
  # However, here we will be inserting a `Child2` inside a `Child1`,
  # which is totally incorrect.
  it "doesn't allow union of generic class with module to be assigned to a generic class with module (#2425)" do
    assert_error <<-CRYSTAL, "instance variable '@value' of Bar must be PluginContainer(Plugin), not PluginContainer(Foo)"
      module Plugin
      end

      class PluginContainer(T)
      end

      class Foo
        include Plugin
      end

      class Bar
        @value : PluginContainer(Plugin)

        def initialize(@value)
        end
      end

      Bar.new(PluginContainer(Foo).new)
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from class method" do
    assert_type(<<-CRYSTAL) { tuple_of([int32, char]).metaclass }
      class Foo(*T)
        def self.t
          T
        end
      end

      Foo(Int32, Char).t
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from instance method" do
    assert_type(<<-CRYSTAL) { tuple_of([int32, char]).metaclass }
      class Foo(*T)
        def t
          T
        end
      end

      Foo(Int32, Char).new.t
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from class method through superclass" do
    assert_type(<<-CRYSTAL) { tuple_of([int32, char]).metaclass }
      class Foo(*T)
        def self.t
          T
        end
      end

      class Bar(*T) < Foo(*T)
      end

      Bar(Int32, Char).t
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from instance method through superclass" do
    assert_type(<<-CRYSTAL) { tuple_of([int32, char]).metaclass }
      class Foo(*T)
        def t
          T
        end
      end

      class Bar(*T) < Foo(*T)
      end

      Bar(Int32, Char).new.t
      CRYSTAL
  end

  it "splats generic type var" do
    assert_type(<<-CRYSTAL) { tuple_of([int32.metaclass, char.metaclass]) }
      class Foo(X, Y)
        def self.vars
          {X, Y}
        end
      end

      Foo(*{Int32, Char}).vars
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from instance method, more args" do
    assert_type(<<-CRYSTAL) { tuple_of([tuple_of([int32, float64]).metaclass, char.metaclass]) }
      class Foo(*T, R)
        def t
          {T, R}
        end
      end

      Foo(Int32, Float64, Char).new.t
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from instance method, more args (2)" do
    assert_type(<<-CRYSTAL) { tuple_of([int32.metaclass, tuple_of([float64]).metaclass, char.metaclass]) }
      class Foo(A, *T, R)
        def t
          {A, T, R}
        end
      end

      Foo(Int32, Float64, Char).new.t
      CRYSTAL
  end

  it "instantiates generic variadic class, accesses T from instance method through superclass, more args" do
    assert_type(<<-CRYSTAL) { tuple_of([string.metaclass, tuple_of([int32, char]).metaclass, float64.metaclass]) }
      class Foo(A, *T, B)
        def t
          {A, T, B}
        end
      end

      class Bar(*T) < Foo(String, *T, Float64)
      end

      Bar(Int32, Char).new.t
      CRYSTAL
  end

  it "virtual metaclass type implements super virtual metaclass type (#3007)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Base
      end

      class Child < Base
      end

      class Child1 < Child
      end

      class Gen(T)
        class Entry(T)
          def initialize(@x : T)
          end

          def foo
            1
          end
        end

        def foo(x)
          Entry(T).new(x).foo
        end
      end

      gen = Gen(Base.class).new
      gen.foo(Child || Child1)
      CRYSTAL
  end

  it "can use virtual type for generic class" do
    assert_type(<<-CRYSTAL) { union_of int32, char }
      class Foo(T)
        def foo
          1
        end
      end

      class Bar(T) < Foo(T)
        def foo
          'a'
        end
      end

      class Baz
        def initialize(@foo : Foo(Int32))
        end

        def foo
          @foo.foo
        end
      end

      baz = Baz.new(Bar(Int32).new)
      baz.foo
      CRYSTAL
  end

  it "recomputes on new subclass" do
    assert_type(<<-CRYSTAL) { union_of(int32, char) }
      class Foo(T)
        def foo
          1
        end
      end

      class Bar(T) < Foo(T)
        def foo
          1
        end
      end

      class Qux(T) < Bar(T)
        def foo
          'a'
        end
      end

      class Baz
        def initialize(@foo : Foo(Int32))
        end

        def foo
          @foo.foo
        end
      end

      baz = Baz.new(Bar(Int32).new)
      baz.foo

      baz = Baz.new(Qux(Int32).new)
      baz.foo
      CRYSTAL
  end

  it "types macro def with generic instance" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { string }
      class Reference
        def foo
          {{ @type.name.stringify }}
        end
      end

      class At
      end

      class Bt(T) < At
      end

      a = Pointer(At).malloc(1_u64)
      a.value = Bt(Int32).new
      a.value.foo
      CRYSTAL
  end

  it "unifies generic metaclass types" do
    assert_type(<<-CRYSTAL) { generic_class("Foo", int32).metaclass.virtual_type! }
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      Foo(Int32) || Bar(Int32)
      CRYSTAL
  end

  it "doesn't crash when matching restriction against number literal (#3157)" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'Gen(3).new' to be T, not String"
      class Gen(T)
        @value : String?

        def initialize(@value : T)
        end
      end

      Gen(3).new("a")
      CRYSTAL
  end

  it "doesn't crash when matching restriction against number literal (2) (#3157)" do
    assert_error <<-CRYSTAL, "expected type, not NumberLiteral"
      class Cls(T)
        @a : T?
      end

      Cls(3).new
      CRYSTAL
  end

  it "replaces type parameters for virtual types (#3235)" do
    assert_type(<<-CRYSTAL) { generic_class "Array", generic_class("OutgoingPacket", types["Client"]).virtual_type! }
      abstract class Packet(T)
      end

      abstract class OutgoingPacket(T) < Packet(T)
      end

      class Client
      end

      class Connection(T)
        def initialize
          @packets = Array(OutgoingPacket(T)).new
        end

        def packets
          @packets
        end
      end

      Connection(Client).new.packets
      CRYSTAL
  end

  it "nests generics with the same type var (#3297)" do
    assert_type(<<-CRYSTAL) { symbol }
      class Foo(A)
        @a : A

        def initialize(@a : A)
        end

        def a
          @a
        end

        class Bar(A) < Foo(A)
        end
      end

      Foo::Bar.new(:a).a
      CRYSTAL
  end

  it "restricts virtual generic instance type against generic (#3351)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Gen(T)
      end

      class Sub < Gen(String)
      end

      def foo(x : Gen(String))
        1
      end

      foo(Gen(String).new.as(Gen(String)))
      CRYSTAL
  end

  it "subclasses twice with same generic class (#3423)" do
    assert_type(<<-CRYSTAL) { generic_class "Bar", int32 }
      class Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      class Bar(T) < Foo(T)
      end

      Bar(Int32).new
      CRYSTAL
  end

  it "errors if invoking new on private new in generic type (#3485)" do
    assert_error <<-CRYSTAL, "private method 'new' called"
      class Foo(T)
        private def self.new
          super
        end
      end

      Foo(String).new
      CRYSTAL
  end

  it "never types Path as virtual outside generic type parameter (#3989)" do
    assert_type(<<-CRYSTAL) { types["Base"].metaclass }
      class Base
      end

      class Derived < Base
        def initialize(x : Int32)
        end
      end

      class Generic(T)
        def initialize
          T.new
        end

        def t
          T
        end
      end

      Generic(Base).new.t
      CRYSTAL
  end

  it "never types Generic as virtual outside generic type parameter (#3989)" do
    assert_type(<<-CRYSTAL) { generic_class("Base", int32).metaclass }
      class Base(T)
      end

      class Derived(T) < Base(T)
        def initialize(x : Int32)
        end
      end

      class Generic(T)
        def initialize
          T.new
        end

        def t
          T
        end
      end

      Generic(Base(Int32)).new.t
      CRYSTAL
  end

  it "doesn't find T type parameter of current type in superclass (#4604)" do
    assert_error <<-CRYSTAL, "undefined constant "
      class X(T)
        abstract class A(T); end

        class B < A(T)
        end
      end
      CRYSTAL
  end

  it "doesn't find unbound type parameter in main code inside generic type (#6168)" do
    assert_error <<-CRYSTAL, "undefined constant T"
      class Foo(T)
        Foo(T)
      end
      CRYSTAL
  end

  it "can use type var that resolves to number in restriction (#6502)" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", 1.int32 }
      class Foo(N)
        def foo : Foo(N)
          self
        end
      end

      f = Foo(1).new
      f.foo
      CRYSTAL
  end

  it "can use type var that resolves to number in restriction using Int128" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", 1.int128 }
      class Foo(N)
        def foo : Foo(N)
          self
        end
      end

      f = Foo(1_i128).new
      f.foo
      CRYSTAL
  end

  it "doesn't consider unbound generic instantiations as concrete (#7200)" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      module Moo
      end

      abstract class Foo(T)
        include Moo

        def call
          T.as(Int32.class)
        end
      end

      class Bar(T) < Foo(T)
      end

      class MooHolder
        def initialize(@moo : Moo)
        end
      end

      moo = MooHolder.new(Bar(Int32).new)
      moo.@moo.call
      CRYSTAL
  end

  it "shows error due to generic instantiation (#7083)" do
    assert_error <<-CRYSTAL, "method Gen(String)#valid? must return Bool but it is returning Nil", inject_primitives: true
      abstract class Base
      end

      class Gen(T) < Base
        def valid? : Bool
          # true
        end
      end

      class Other < Base
        def valid?
          true
        end
      end

      x = Pointer(Base).malloc(1)
      x.value.valid?

      Gen(String).new
      CRYSTAL
  end

  it "resolves T through metaclass inheritance (#7914)" do
    assert_type(<<-CRYSTAL) { int32 }
      struct Int32
        def self.foo
          1
        end
      end

      class Matrix(T)
        def self.foo
          T.foo
        end
      end

      class GeneralMatrix(T) < Matrix(T)
      end

      GeneralMatrix(Int32).foo
      CRYSTAL
  end

  it "errors if splatting a non-tuple (#9853)" do
    assert_error <<-CRYSTAL, "argument to splat must be a tuple type, not Int32"
      Array(*Int32)
      CRYSTAL
  end

  it "correctly checks argument count when target type has a splat (#9855)" do
    assert_type(<<-CRYSTAL) { generic_class("T", int32, bool).metaclass }
      class T(A, B, *C)
      end

      T(*{Int32, Bool})
      CRYSTAL
  end

  it "restricts generic type argument through alias in a non-strict way" do
    assert_type(<<-CRYSTAL) { generic_class "Gen", int32 }
      class Gen(T)
      end

      alias G = Gen(String | Int32)

      def foo(x : G)
        x
      end

      foo(Gen(Int32).new)
      CRYSTAL
  end

  it "replaces type parameters in virtual metaclasses (#10691)" do
    assert_type(<<-CRYSTAL) { generic_class("Foo", generic_class("Parent", int32).virtual_type.metaclass) }
      class Parent(T)
      end

      class Child < Parent(Int32)
      end

      class Foo(T)
      end

      class Bar(T)
        @foo = Foo(Parent(T).class).new
      end

      Bar(Int32).new.@foo
      CRYSTAL
  end
end
