require 'spec_helper'

describe 'Type inference: range' do
  it "types a range" do
    node = parse 'require "range"; 1..2'
    mod = infer_type node
    node.last.type.should be_a(ObjectType)
    node.last.type.name.should eq('Range')
    node.last.type.type_vars["B"].type.should eq(mod.int)
    node.last.type.type_vars["E"].type.should eq(mod.int)
  end
end
