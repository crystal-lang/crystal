require "./spec_helper"

describe Spec::ExampleGroup do
  describe "#report" do
    it "should include parent's description" do
      root = FakeRootContext.new
      child = Spec::ExampleGroup.new(root, "child", "f.cr", 1, 10, false)
      grand_child = Spec::ExampleGroup.new(child, "grand_child", "f.cr", 2, 9, false)

      grand_child.report(:fail, "oops", "f.cr", 3, nil, nil)

      root.@results[:fail].first.description.should eq("child grand_child oops")
    end
  end
end
