require 'spec_helper'

describe UnionType do
  let(:mod) { Crystal::Program.new }

  it "merge equal types" do
    Type.merge(mod.int32, mod.int32).should eq(mod.int32)
  end

  it "merge distinct types" do
    Type.merge(mod.int32, mod.float32).should eq(mod.union_of(mod.int32, mod.float32))
  end

  it "merge simple type with union" do
    Type.merge(mod.int32, mod.union_of(mod.float32, mod.char)).should eq(mod.union_of(mod.int32, mod.float32, mod.char))
  end

  it "merge union types" do
    Type.merge(mod.union_of(mod.int32, mod.char), mod.union_of(mod.float32, mod.int32)).should eq(mod.union_of(mod.char, mod.float32, mod.int32))
  end
end
