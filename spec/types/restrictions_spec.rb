require 'spec_helper'

describe "Restrictions" do
  let(:mod) { Crystal::Program.new }

  def t(type)
    if type.end_with?("+")
      mod.types[type[0 .. -2]].hierarchy_type
    else
      mod.types[type]
    end
  end

  describe "restrict" do
    it "restricts type with same type" do
      mod.int32.restrict(mod.int32).should eq(mod.int32)
    end

    it "restricts type with another type" do
      mod.int32.restrict(mod.int16).should be_nil
    end

    it "restricts type with superclass" do
      mod.int32.restrict(mod.value).should eq(mod.int32)
    end

    it "restricts type with included module" do
      mod.infer_type parse(%(
        module Mod
        end

        class Foo
          include Mod
        end
      ))

      mod.types["Foo"].restrict(mod.types["Mod"]).should eq(mod.types["Foo"])
    end

    it "restricts hierarchy type with included module 1" do
      mod.infer_type parse(%(
        module M; end
        class A; include M; end
      ))

      t("A+").restrict(t("M")).should eq(t("A+"))
    end

    it "restricts hierarchy type with included module 2" do
      mod.infer_type parse(%(
        module M; end
        class A; end
        class B < A; include M; end
        class C < A; include M; end
        class D < C; end
        class E < A; end
      ))

      t("A+").restrict(t("M")).should eq(mod.union_of(t("B+"), t("C+")))
    end
  end
end
