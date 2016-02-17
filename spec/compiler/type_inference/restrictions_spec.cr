require "../../spec_helper"

class Crystal::Program
  def t(type)
    if type.ends_with?('+')
      types[type[0..-2]].virtual_type
    else
      types[type]
    end
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
      mod.infer_type parse("
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
      mod.infer_type parse("
        module M; end
        class A; include M; end
      ")

      mod.t("A+").restrict(mod.t("M"), MatchContext.new(mod, mod)).should eq(mod.t("A+"))
    end

    it "restricts virtual type with included module 2" do
      mod = Program.new
      mod.infer_type parse("
        module M; end
        class A; end
        class B < A; include M; end
        class C < A; include M; end
        class D < C; end
        class E < A; end
      ")

      mod.t("A+").restrict(mod.t("M"), MatchContext.new(mod, mod)).should eq(mod.union_of(mod.t("B+"), mod.t("C+")))
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
        macro def self.foo : self
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
      def bar(x : String, y = nil : String)
      end

      bar(1 || "")
      ),
      "no overload matches"
  end

  it "errors on T::Type that's union when used from type restriction" do
    assert_error %(
      def foo(x : T)
        T::Baz
      end

      foo(1 || 1.5)
      ),
      "can't lookup type in union (Int32 | Float64)"
  end

  it "errors on T::Type that's a union when used from block type restriction" do
    assert_error %(
      class Foo(T)
        def self.foo(&block : T::Baz ->)
        end
      end

      Foo(Int32 | Float64).foo { 1 + 2 }
      ),
      "can't lookup type in union (Int32 | Float64)"
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
      )) { union_of(
      (types["Foo"] as GenericClassType).instantiate([int32] of TypeVar),
      (types["Foo"] as GenericClassType).instantiate([float64] of TypeVar),
    ) }
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

      def bar(other : Bar(Y))
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
      class A; end

      class B < A; end

      def foo : A.class # offending return type restriction
        B
      end

      foo
      )) { types["B"].metaclass }
  end
end
