require 'spec_helper'

describe 'Type inference: regexp' do
  it "types a regexp" do
    node = parse 'require "prelude"; /foo/'
    mod, node = infer_type node
    node.last.type.should be_class
    node.last.type.name.should eq('Regexp')
  end
end
