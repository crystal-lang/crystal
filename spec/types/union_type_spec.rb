require 'spec_helper'

describe UnionType do
  let(:mod) { Crystal::Module.new }

  it "compares to single type" do
    union = UnionType.new(mod.int)
    union.should eq(mod.int)
    union.should_not eq(mod.float)
  end

  it "compares to union type" do
    union1 = UnionType.new(mod.int, mod.float)
    union2 = UnionType.new(mod.float, mod.int)
    union3 = UnionType.new(mod.float, mod.int, mod.char)

    union1.should eq(union2)
    union1.should_not eq(union3)
  end

  it "compares single type to union" do
    mod.int.should eq(UnionType.new(mod.int))
    mod.int.should_not eq(UnionType.new(mod.int, mod.float))
  end

  it "merge equal types" do
    Type.merge(mod.int, mod.int).should eq(mod.int)
  end

  it "merge distinct types" do
    Type.merge(mod.int, mod.float).should eq(UnionType.new(mod.int, mod.float))
  end

  it "merge simple type with union" do
    Type.merge(mod.int, UnionType.new(mod.float, mod.char)).should eq(UnionType.new(mod.int, mod.float, mod.char))
  end

  it "merge union types" do
    Type.merge(UnionType.new(mod.int, mod.char), UnionType.new(mod.float, mod.int)).should eq(UnionType.new(mod.char, mod.float, mod.int))
  end
end
