#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Restrictions" do
  def t(mod, type)
    if type.ends_with?('+')
      mod.types[type[0 .. -2]].virtual_type
    else
      mod.types[type]
    end
  end

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

      t(mod, "A+").restrict(t(mod, "M"), MatchContext.new(mod, mod)).should eq(t(mod, "A+"))
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

      t(mod, "A+").restrict(t(mod, "M"), MatchContext.new(mod, mod)).should eq(mod.union_of(t(mod, "B+"), t(mod, "C+")))
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
end
