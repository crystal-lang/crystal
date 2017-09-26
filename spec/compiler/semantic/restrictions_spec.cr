require "../../spec_helper"

class Crystal::Program
  def t(type)
    types[type.rchop('+')].virtual_type
  end
end

describe "Restrictions" do
  describe "restrict" do
    it "restricts type with same type" do
      mod = Program.new
      mod.int32.restrict(mod.int32, MatchContext.new(mod, mod)).should eq(mod.int32)
    end

    it "restricts type with another type" do
      mod = Program.new
      mod.int32.restrict(mod.int16, MatchContext.new(mod, mod)).should be_nil
    end

    it "restricts type with superclass" do
      mod = Program.new
      mod.int32.restrict(mod.value, MatchContext.new(mod, mod)).should eq(mod.int32)
    end

    it "restricts type with included module" do
      mod = Program.new
      mod.semantic parse("
        module Mod
        end

        class Foo
          include Mod
        end
      ")

      mod.types["Foo"].restrict(mod.types["Mod"], MatchContext.new(mod, mod)).should eq(mod.types["Foo"])
    end

    it "restricts virtual type with included module 1" do
      mod = Program.new
      mod.semantic parse("
        module Moo; end
        class Foo; include Moo; end
      ")

      mod.t("Foo+").restrict(mod.t("Moo"), MatchContext.new(mod, mod)).should eq(mod.t("Foo+"))
    end

    it "restricts virtual type with included module 2" do
      mod = Program.new
      mod.semantic parse("
        module Mxx; end
        class Axx; end
        class Bxx < Axx; include Mxx; end
        class Cxx < Axx; include Mxx; end
        class Dxx < Cxx; end
        class Exx < Axx; end
      ")

      mod.t("Axx+").restrict(mod.t("Mxx"), MatchContext.new(mod, mod)).should eq(mod.union_of(mod.t("Bxx+"), mod.t("Cxx+")))
    end
  end

  it "self always matches instance type in restriction" do
    assert_type(%(
      class Foo
        def self.foo(x : self)
          x
        end
      end

      Foo.foo Foo.new
      )) { types["Foo"] }
  end

  it "self always matches instance type in return type" do
    assert_type(%(
      class Foo
        def self.foo : self
          {{ @type }}
          Foo.new
        end
      end
      Foo.foo
      )) { types["Foo"] }
  end

  it "allows typeof as restriction" do
    assert_type(%(
      struct Int32
        def self.foo(x : typeof(self))
          x
        end
      end

      Int32.foo 1
      )) { int32 }
  end

  it "passes #278" do
    assert_error %(
      def bar(x : String, y : String = nil)
      end

      bar(1 || "")
      ),
      "no overload matches"
  end

  it "errors on T::Type that's union when used from type restriction" do
    assert_error %(
      def foo(x : T) forall T
        T::Baz
      end

      foo(1 || 1.5)
      ),
      "undefined constant T::Baz"
  end

  it "errors on T::Type that's a union when used from block type restriction" do
    assert_error %(
      class Foo(T)
        def self.foo(&block : T::Baz ->)
        end
      end

      Foo(Int32 | Float64).foo { 1 + 2 }
      ),
      "undefined constant T::Baz"
  end

  it "errors if can't find type on lookup" do
    assert_error %(
      def foo(x : Something)
      end

      foo 1
      ), "undefined constant Something"
  end

  it "errors if can't find type on lookup with nested type" do
    assert_error %(
      def foo(x : Foo::Bar)
      end

      foo 1
      ), "undefined constant Foo::Bar"
  end

  it "works with static array (#637)" do
    assert_type(%(
      def foo(x : UInt8[1])
        1
      end

      def foo(x : UInt8[2])
        'a'
      end

      x = uninitialized UInt8[2]
      foo(x)
      )) { char }
  end

  it "works with static array that uses underscore" do
    assert_type(%(
      def foo(x : UInt8[_])
        'a'
      end

      x = uninitialized UInt8[2]
      foo(x)
      )) { char }
  end

  it "works with generic compared to fixed (primitive) type" do
    assert_type(%(
      class Foo(T)
      end

      struct Float64
        def /(other : Foo(_))
          'a'
        end
      end

      1.5 / Foo(Int32).new
      )) { char }
  end

  it "works with generic class metaclass vs. generic instance class metaclass" do
    assert_type(%(
      class Foo(T)
      end

      def foo(x : Foo(Int32).class)
        1
      end

      foo Foo(Int32)
      )) { int32 }
  end

  it "works with generic class metaclass vs. generic class metaclass" do
    assert_type(%(
      class Foo(T)
      end

      def foo(x : Foo.class)
        1
      end

      foo Foo(Int32)
      )) { int32 }
  end

  it "works with union against unions of generics" do
    assert_type(%(
      class Foo(T)
      end

      def foo(x : Foo | Int32)
        x
      end

      foo(Foo(Int32).new || Foo(Float64).new)
      )) { union_of(generic_class("Foo", int32), generic_class("Foo", float64)) }
  end

  it "should not let GenericChild(Base) pass as a GenericBase(Child) (#1294)" do
    assert_error %(
      class Base
      end

      class Child < Base
      end

      class GenericBase(T)
      end

      class GenericChild(T) < GenericBase(T)
      end

      def foo(x : GenericBase(Child))
      end

      foo GenericChild(Base).new
      ),
      "no overload matches"
  end

  it "allows passing recursive type to free var (#1076)" do
    assert_type(%(
      class Foo(T)
      end

      alias NestedParams = Nil | Foo(NestedParams)

      class Bar(X)
      end

      def bar(other : Bar(Y)) forall Y
        'a'
      end

      h1 = Bar(NestedParams).new
      bar(h1)
      )) { char }
  end

  it "restricts class union type to overloads with classes" do
    assert_type(%(
      def foo(x : Int32.class)
        1_u8
      end

      def foo(x : String.class)
        1_u16
      end

      def foo(x : Bool.class)
        1_u32
      end

      a = 1 || "foo" || true
      foo(a.class)
      )) { union_of([uint8, uint16, uint32] of Type) }
  end

  it "restricts class union type to overloads with classes (2)" do
    assert_type(%(
      def foo(x : Int32.class)
        1_u8
      end

      def foo(x : String.class)
        1_u16
      end

      def foo(x : Bool.class)
        1_u32
      end

      a = 1 || "foo"
      foo(a.class)
      )) { union_of([uint8, uint16] of Type) }
  end

  it "makes metaclass subclass pass parent metaclass restriction (#2079)" do
    assert_type(%(
      class Foo; end

      class Bar < Foo; end

      def foo : Foo.class # offending return type restriction
        Bar
      end

      foo
      )) { types["Bar"].metaclass }
  end

  it "matches virtual type against alias" do
    assert_type(%(
      module Moo
      end

      class Foo
        include Moo
      end

      class Bar < Foo
      end

      class Baz < Bar
      end

      alias Alias = Moo

      def foo(x : Alias)
        1
      end

      foo(Baz.new.as(Bar))
      )) { int32 }
  end

  it "matches alias against alias in block type" do
    assert_type(%(
      class Foo(T)
        def self.new(&block : -> T)
          Foo(T).new
        end

        def initialize
        end

        def t
          T
        end
      end

      alias Rec = Nil | Array(Rec)

      Foo.new { nil.as(Rec)}.t
      )) { types["Rec"].metaclass }
  end

  it "matches free variable for type variable" do
    assert_type(%(
      class Foo(Type)
        def initialize(x : Type)
        end
      end

      Foo.new(1)
      )) { generic_class "Foo", int32 }
  end

  it "restricts virtual metaclass type against metaclass (#3438)" do
    assert_type(%(
      class Parent
      end

      class Child < Parent
      end

      def foo(x : Parent.class)
        x
      end

      foo(Parent || Child)
      )) { types["Parent"].metaclass.virtual_type! }
  end

  it "doesn't crash on invalid splat restriction (#3698)" do
    assert_error %(
      def foo(arg : *String)
      end

      foo(1)
      ),
      "no overload matches"
  end

  it "errors if using free var without forall" do
    assert_error %(
      def foo(x : T)
        T
      end

      foo(1)
      ),
      "undefined constant T"
  end
end
