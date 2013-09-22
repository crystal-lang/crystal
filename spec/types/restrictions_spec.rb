require 'spec_helper'

describe "Restrictions" do
  let(:mod) { Crystal::Program.new }

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

    it "restricts hierarchy type with included module" do
      mod.infer_type parse(%(
        module Mod
        end

        class Foo
        end

        class Bar < Foo
          include Mod
        end

        class Bar2 < Foo
          include Mod
        end

        class Bar3 < Foo
        end
      ))

      mod.types["Foo"].hierarchy_type.restrict(mod.types["Mod"]).should eq(mod.union_of(mod.types["Bar"], mod.types["Bar2"]))
    end
  end
end
