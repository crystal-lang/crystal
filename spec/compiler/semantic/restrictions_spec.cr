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

    it "restricts module with another module" do
      mod = Program.new
      mod.semantic parse("
        module Mxx; end
        module Nxx; end
        class Axx; include Mxx; end
        class Bxx; include Nxx; end
        class Cxx; include Mxx; include Nxx; end
        class Dxx < Axx; include Nxx; end
        class Exx < Bxx; include Mxx; end
      ")

      mod.t("Mxx").restrict(mod.t("Nxx"), MatchContext.new(mod, mod)).should eq(mod.union_of(mod.t("Cxx"), mod.t("Dxx"), mod.t("Exx")))
    end

    it "restricts generic module instance with another module" do
      mod = Program.new
      mod.semantic parse("
        module Mxx(T); end
        module Nxx; end
        class Axx; include Mxx(Int32); end
        class Bxx; include Nxx; end
        class Cxx; include Mxx(Int32); include Nxx; end
        class Dxx < Axx; include Nxx; end
        class Exx < Bxx; include Mxx(Int32); end
      ")

      result = mod.generic_module("Mxx", mod.int32).restrict(mod.t("Nxx"), MatchContext.new(mod, mod))
      result.should eq(mod.union_of(mod.t("Cxx"), mod.t("Dxx"), mod.t("Exx")))
    end

    it "restricts generic module instance with another generic module instance" do
      mod = Program.new
      mod.semantic parse("
        module Mxx(T); end
        module Nxx(T); end
        class Axx; include Mxx(Int32); end
        class Bxx; include Nxx(Int32); end
        class Cxx; include Mxx(Int32); include Nxx(Int32); end
        class Dxx < Axx; include Nxx(Int32); end
        class Exx < Bxx; include Mxx(Int32); end
        class Fxx; include Mxx(Int32); include Nxx(Char); end
        class Gxx; include Mxx(Char); include Nxx(Int32); end
      ")

      result = mod.generic_module("Mxx", mod.int32).restrict(mod.generic_module("Nxx", mod.int32), MatchContext.new(mod, mod))
      result.should eq(mod.union_of(mod.t("Cxx"), mod.t("Dxx"), mod.t("Exx")))
    end

    it "restricts generic module instance with class" do
      mod = Program.new
      mod.semantic parse("
        module Mxx(T); end
        module Nxx; end
        class Axx; include Mxx(Int32); end
        class Bxx; include Nxx; end
        class Cxx; include Mxx(Int32); include Nxx; end
        class Dxx < Axx; include Nxx; end
        class Exx < Bxx; include Mxx(Int32); end
      ")

      result = mod.generic_module("Mxx", mod.int32).restrict(mod.t("Nxx"), MatchContext.new(mod, mod))
      result.should eq(mod.union_of(mod.t("Cxx"), mod.t("Dxx"), mod.t("Exx")))
    end

    it "restricts module through generic include (#4287)" do
      mod = Program.new
      mod.semantic parse("
        module Axx; end
        module Bxx(T); include Axx; end
        class Cxx; include Bxx(Int32); end
      ")

      mod.t("Axx").restrict(mod.t("Cxx"), MatchContext.new(mod, mod)).should eq(mod.t("Cxx"))
    end

    it "restricts class against uninstantiated generic base class through multiple inheritance (1) (#9660)" do
      mod = Program.new
      mod.semantic parse("
        class Axx(T); end
        class Bxx(T) < Axx(T); end
        class Cxx < Bxx(Int32); end
      ")

      result = mod.t("Cxx").restrict(mod.t("Axx"), MatchContext.new(mod, mod))
      result.should eq(mod.t("Cxx"))
    end

    it "restricts class against uninstantiated generic base class through multiple inheritance (2) (#9660)" do
      mod = Program.new
      mod.semantic parse("
        class Axx(T); end
        class Bxx(T) < Axx(T); end
        class Cxx(T) < Bxx(T); end
      ")

      result = mod.generic_class("Cxx", mod.int32).restrict(mod.t("Axx"), MatchContext.new(mod, mod))
      result.should eq(mod.generic_class("Cxx", mod.int32))
    end

    it "restricts virtual generic class against uninstantiated generic subclass (1)" do
      mod = Program.new
      mod.semantic parse("
        class Axx(T); end
        class Bxx(T) < Axx(T); end
        class Cxx < Bxx(Int32); end
      ")

      result = mod.generic_class("Axx", mod.int32).virtual_type.restrict(mod.generic_class("Bxx", mod.int32), MatchContext.new(mod, mod))
      result.should eq(mod.generic_class("Bxx", mod.int32).virtual_type)
    end

    it "restricts virtual generic class against uninstantiated generic subclass (2)" do
      mod = Program.new
      mod.semantic parse("
        class Axx(T); end
        class Bxx(T) < Axx(T); end
        class Cxx(T) < Bxx(T); end
      ")

      result = mod.generic_class("Axx", mod.int32).virtual_type.restrict(mod.generic_class("Bxx", mod.int32), MatchContext.new(mod, mod))
      result.should eq(mod.generic_class("Bxx", mod.int32).virtual_type)
    end
  end

  describe "restriction_of?" do
    describe "Metaclass vs Metaclass" do
      it "inserts typed Metaclass before untyped Metaclass" do
        assert_type(%(
          def foo(a : T.class) forall T
            1
          end

          def foo(a : Int32.class)
            true
          end

          foo(Int32)
          )) { bool }
      end

      it "keeps typed Metaclass before untyped Metaclass" do
        assert_type(%(
          def foo(a : Int32.class)
            true
          end

          def foo(a : T.class) forall T
            1
          end

          foo(Int32)
          )) { bool }
      end
    end

    describe "Path vs Path" do
      it "inserts typed Path before untyped Path" do
        assert_type(%(
          def foo(a : T) forall T
            1
          end

          def foo(a : Int32)
            true
          end

          foo(1)
          )) { bool }
      end

      it "keeps typed Path before untyped Path" do
        assert_type(%(
          def foo(a : Int32)
            true
          end

          def foo(a : T) forall T
            1
          end

          foo(1)
          )) { bool }
      end
    end

    describe "Generic vs Path" do
      it "inserts typed Generic before untyped Path" do
        assert_type(%(
          def foo(a : T) forall T
            1
          end

          def foo(a : Array(Int32))
            true
          end

          foo(Array(Int32).new)
          )) { bool }
      end

      it "keeps typed Generic before untyped Path" do
        assert_type(%(
          def foo(a : Array(Int32))
            true
          end

          def foo(a : T) forall T
            1
          end

          foo(Array(Int32).new)
          )) { bool }
      end

      it "inserts untyped Generic before untyped Path" do
        assert_type(%(
          def foo(a : T) forall T
            1
          end

          def foo(a : Array(T)) forall T
            true
          end

          foo(Array(Int32).new)
          )) { bool }
      end

      it "inserts untyped Generic before untyped Path (2)" do
        assert_type(%(
          def foo(a : T) forall T
            1
          end

          def foo(a : Array)
            true
          end

          foo(Array(Int32).new)
          )) { bool }
      end

      it "keeps untyped Generic before untyped Path" do
        assert_type(%(
          def foo(a : Array(T)) forall T
            true
          end

          def foo(a : T) forall T
            1
          end

          foo(Array(Int32).new)
          )) { bool }
      end
    end

    describe "Generic vs Generic" do
      it "inserts typed Generic before untyped Generic" do
        assert_type(%(
          def foo(a : Array(T)) forall T
            1
          end

          def foo(a : Array(Int32))
            true
          end

          foo(Array(Int32).new)
          )) { bool }
      end

      it "keeps typed Generic before untyped Generic" do
        assert_type(%(
          def foo(a : Array(Int32))
            true
          end

          def foo(a : Array(T)) forall T
            1
          end

          foo(Array(Int32).new)
          )) { bool }
      end
    end

    describe "GenericClassType vs GenericClassInstanceType" do
      it "inserts GenericClassInstanceType before GenericClassType" do
        assert_type(%(
          class Foo(T)
          end

          def bar(a : Foo)
            1
          end

          def bar(a : Foo(Int32))
            true
          end

          {
            bar(Foo(Int32).new),
            bar(Foo(Float64).new)
          }
          )) { tuple_of([bool, int32]) }
      end

      it "keeps GenericClassInstanceType before GenericClassType" do
        assert_type(%(
          class Foo(T)
          end

          def bar(a : Foo(Int32))
            true
          end

          def bar(a : Foo)
            1
          end

          {
            bar(Foo(Int32).new),
            bar(Foo(Float64).new)
          }
          )) { tuple_of([bool, int32]) }
      end

      it "works with classes in different namespaces" do
        assert_type(%(
          class Foo(T)
          end

          class Mod::Foo(G)
          end

          def bar(a : Foo(Int32))
            true
          end

          def bar(a : Mod::Foo)
            1
          end

          {
            bar(Foo(Int32).new),
            bar(Mod::Foo(Int32).new)
          }
          )) { tuple_of([bool, int32]) }
      end

      it "doesn't mix different generic classes" do
        assert_type(%(
          class Foo(T)
          end

          class Bar(U)
          end

          def bar(a : Bar(Int32))
            true
          end

          def bar(a : Foo)
            1
          end

          {
            bar(Foo(Int32).new),
            bar(Bar(Int32).new)
          }
          )) { tuple_of([int32, bool]) }
      end
    end

    describe "NamedTuple vs NamedTuple" do
      it "inserts more specialized NamedTuple before less specialized one" do
        assert_type(%(
          class Foo
          end

          class Bar < Foo
          end

          def foo(a : NamedTuple(x: Foo))
            1
          end

          def foo(a : NamedTuple(x: Bar))
            true
          end

          foo({x: Bar.new})
          )) { bool }
      end

      it "keeps more specialized NamedTuple before less specialized one" do
        assert_type(%(
          class Foo
          end

          class Bar < Foo
          end

          def foo(a : NamedTuple(x: Bar))
            true
          end

          def foo(a : NamedTuple(x: Foo))
            1
          end

          foo({x: Bar.new})
          )) { bool }
      end

      it "doesn't mix incompatible NamedTuples (#10238)" do
        assert_type(%(
          def foo(a : NamedTuple(a: Int32))
            1
          end

          def foo(a : NamedTuple(b: Int32))
            true
          end

          {
            foo({a: 1}),
            foo({b: 1})
          }
          )) { tuple_of([int32, bool]) }
      end
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

  it "errors if using typeof" do
    assert_error %(
      def foo(x : typeof(1))
      end

      foo(1)
      ),
      "can't use typeof in type restrictions"
  end

  it "errors if using typeof inside generic type" do
    assert_error %(
      class Gen(T)
      end

      def foo(x : Gen(typeof(1)))
      end

      foo(Gen(Int32).new)
      ),
      "can't use typeof in type restrictions"
  end

  it "errors if using typeof in block restriction" do
    assert_error %(
      def foo(&x : typeof(1) -> )
        yield 1
      end

      foo {}
      ),
      "can't use 'typeof' here"
  end

  it "errors if using typeof in block restriction" do
    assert_error %(
      def foo(&x : -> typeof(1))
        yield
      end

      foo {}
      ),
      "can't use typeof in type restriction"
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

  it "errors if using free var without forall" do
    assert_error %(
      def foo(x : T)
        T
      end

      foo(1)
      ),
      "undefined constant T"
  end

  it "sets number as free variable (#2699)" do
    assert_error %(
      def foo(x : T[N], y : T[N]) forall T, N
      end

      x = uninitialized UInt8[10]
      y = uninitialized UInt8[11]
      foo(x, y)
      ),
      "no overload matches"
  end

  it "gives precedence to T.class over Class (#7392)" do
    assert_type(%(
      def foo(x : Class)
        'a'
      end

      def foo(x : Int32.class)
        1
      end

      foo(Int32)
      )) { int32 }
  end

  it "restricts aliased typedef type (#9474)" do
    assert_type(%(
      lib A
        alias B = Int32
      end

      alias C = A::B

      def foo(x : C)
        1
      end

      x = uninitialized C
      foo x
      )) { int32 }
  end
end
