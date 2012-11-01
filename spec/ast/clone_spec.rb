require 'spec_helper'

describe "ast clone" do
  it "clones with block" do
    nodes = parse 'def x; y; end'
    others = nodes.clone do |old_node, new_node|
      new_node.name = "#{old_node.name}2"
    end
    others.to_s.should eq("def x2\n  y2()\nend")
  end
end
