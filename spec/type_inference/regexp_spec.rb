require 'spec_helper'

describe 'Type inference: regexp' do
  it "types a regexp" do
    node = parse '/foo/'
    mod = infer_type node, load_std: ['c', 'io', 'string', 'regexp']
    node.type.should be_a(ObjectType)
    node.type.name.should eq('Regexp')
  end
end
