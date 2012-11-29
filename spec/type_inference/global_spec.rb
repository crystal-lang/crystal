require 'spec_helper'

describe 'Global inference' do
  it "infers type of global assign" do
    node = parse '$foo = 1'
    mod = infer_type node
    node.type.should eq(mod.int)
    node.target.type.should eq(mod.int)
    node.value.type.should eq(mod.int)
  end

  it "infers type of global assign with union" do
    nodes = parse '$foo = 1; $foo = 2.5'
    mod = infer_type nodes
    nodes[0].target.type.should eq([mod.int, mod.float].union)
    nodes[1].target.type.should eq([mod.int, mod.float].union)
  end

  it "infers type of global reference" do
    assert_type("$foo = 1; def foo; $foo = 2.5; end; foo; $foo") { [int, float].union }
  end
end
