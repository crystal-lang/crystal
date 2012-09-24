require 'spec_helper'

describe 'Type inference: while' do
  it "types while" do
    nodes = parse 'while true; 1; end'
    mod = infer_type nodes
    nodes.first.type.should eq(mod.void)
  end
end