require 'spec_helper'

describe UnionType do
  let(:mod) { Crystal::Program.new }

  it "merge equal types" do
    Type.merge(mod.int, mod.int).should eq(mod.int)
  end

  it "merge distinct types" do
    Type.merge(mod.int, mod.float).should eq(mod.union_of(mod.int, mod.float))
  end

  it "merge simple type with union" do
    Type.merge(mod.int, mod.union_of(mod.float, mod.char)).should eq(mod.union_of(mod.int, mod.float, mod.char))
  end

  it "merge union types" do
    Type.merge(mod.union_of(mod.int, mod.char), mod.union_of(mod.float, mod.int)).should eq(mod.union_of(mod.char, mod.float, mod.int))
  end
end
