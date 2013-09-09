require 'spec_helper'

describe 'Type inference: responds_to?' do
  it "is bool" do
    assert_type("1.responds_to?(:foo)") { bool }
  end

  it "restricts type inside if scope 1" do
    nodes = parse %q(
      a = 1 || 'a'
      if a.responds_to?(:"+")
        a
      end
      )
    mod, nodes = infer_type nodes
    nodes.last.then.type.should eq(mod.int32)
  end

  it "restricts other types inside if else" do
    assert_type(%q(
      a = 1 || 'a'
      if a.responds_to?(:"+")
        a.to_i32
      else
        a.ord
      end
      )) { int32 }
  end
end
