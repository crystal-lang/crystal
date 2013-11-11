#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Restrictions" do
  def t(mod, type)
    if type.ends_with?('+')
      mod.types[type[0 .. -2]].hierarchy_type
    else
      mod.types[type]
    end
  end

  describe "restrict" do
    it "restricts type with same type" do
      mod = Program.new
      mod.int32.restrict(mod.int32, nil, nil, nil).should eq(mod.int32)
    end

    it "restricts type with another type" do
      mod = Program.new
      mod.int32.restrict(mod.int16, nil, nil, nil).should be_nil
    end

    it "restricts type with superclass" do
      mod = Program.new
      mod.int32.restrict(mod.value, nil, nil, nil).should eq(mod.int32)
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

      mod.types["Foo"].restrict(mod.types["Mod"], nil, nil, nil).should eq(mod.types["Foo"])
    end

    it "restricts hierarchy type with included module 1" do
      mod = Program.new
      mod.infer_type parse("
        module M; end
        class A; include M; end
      ")

      t(mod, "A+").restrict(t(mod, "M"), nil, nil, nil).should eq(t(mod, "A+"))
    end

    it "restricts hierarchy type with included module 2" do
      mod = Program.new
      mod.infer_type parse("
        module M; end
        class A; end
        class B < A; include M; end
        class C < A; include M; end
        class D < C; end
        class E < A; end
      ")

      t(mod, "A+").restrict(t(mod, "M"), nil, nil, nil).should eq(mod.union_of(t(mod, "B+"), t(mod, "C+")))
    end
  end
end
