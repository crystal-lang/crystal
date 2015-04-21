require "../../spec_helper"

class Crystal::Program
  def t(type)
    if type.ends_with?('+')
      types[type[0 .. -2]].virtual_type
    else
      types[type]
    end
  end
end

describe "Restrictions" do
  describe "restrict" do
    it "restricts type with same type" do
      mod = Program.new
      expect(mod.int32.restrict(mod.int32, MatchContext.new(mod, mod))).to eq(mod.int32)
    end

    it "restricts type with another type" do
      mod = Program.new
      expect(mod.int32.restrict(mod.int16, MatchContext.new(mod, mod))).to be_nil
    end

    it "restricts type with superclass" do
      mod = Program.new
      expect(mod.int32.restrict(mod.value, MatchContext.new(mod, mod))).to eq(mod.int32)
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

      expect(mod.types["Foo"].restrict(mod.types["Mod"], MatchContext.new(mod, mod))).to eq(mod.types["Foo"])
    end

    it "restricts virtual type with included module 1" do
      mod = Program.new
      mod.infer_type parse("
        module M; end
        class A; include M; end
      ")

      expect(mod.t("A+").restrict(mod.t("M"), MatchContext.new(mod, mod))).to eq(mod.t("A+"))
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

      expect(mod.t("A+").restrict(mod.t("M"), MatchContext.new(mod, mod))).to eq(mod.union_of(mod.t("B+"), mod.t("C+")))
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
end
