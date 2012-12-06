require 'spec_helper'

describe 'Type inference: range' do
  it "types a range" do
    node = parse '1..2'
    mod = infer_type node, load_std: 'range'
    node.type.should be_a(ObjectType)
    node.type.name.should eq('Range')
  end
end
