require 'spec_helper'

describe 'Type inference: range' do
  it "types a range" do
    node = parse 'require "range"; 1..2'
    mod, node = infer_type node
    node.last.type.should be_class
    node.last.type.generic_class.name.should eq('Range')
    node.last.type.type_vars["B"].type.should eq(mod.int)
    node.last.type.type_vars["E"].type.should eq(mod.int)
  end

  it "types range literal method call" do
    assert_type(%(require "range"; (1..2).begin)) { int }
  end

  it "types range literal to_a" do
    assert_type(%q(
      require "prelude"
      a = 1 .. 5
      a.to_a
      )) { array_of(int) }
  end
end
