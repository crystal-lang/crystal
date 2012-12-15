require 'spec_helper'

describe 'Type inference: regexp' do
  it "types a regexp" do
    node = parse 'require "c"; require "io"; require "string"; require "regexp"; /foo/'
    mod = infer_type node
    node.last.type.should be_a(ObjectType)
    node.last.type.name.should eq('Regexp')
  end
end
