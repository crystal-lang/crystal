require 'spec_helper'

describe 'Global inference' do
  it "infers type of global assign" do
    node = parse '$foo = 1'
    mod, node = infer_type node
    node.type.should eq(mod.int32)
    node.target.type.should eq(mod.int32)
    node.value.type.should eq(mod.int32)
  end

  it "infers type of global assign with union" do
    nodes = parse '$foo = 1; $foo = 2.5'
    mod, nodes = infer_type nodes
    nodes[0].target.type.should eq(mod.union_of(mod.int32, mod.float64))
    nodes[1].target.type.should eq(mod.union_of(mod.int32, mod.float64))
  end

  it "infers type of global reference" do
    assert_type("$foo = 1; def foo; $foo = 2.5; end; foo; $foo") { union_of(int32, float64) }
  end

  it "infers type of read global variable when not previously assigned" do
    assert_type("def foo; $foo; end; foo; $foo") { self.nil }
  end

  it "infers type of write global variable when not previously assigned" do
    assert_type("def foo; $foo = 1; end; foo; $foo") { union_of(self.nil, int32) }
  end
end
