require "./spec_helper"

describe Spec::ExampleGroup do
  describe "#randomize" do
    it "by default" do
      root = build_spec("f.cr", count: 20)

      before_randomize = all_spec_descriptions(root)
      root.randomize(Random::DEFAULT)
      after_randomize = all_spec_descriptions(root)

      after_randomize.should_not eq before_randomize
      after_randomize.sort.should eq before_randomize.sort
    end

    it "with a seed" do
      seed = 12345_u64

      root = build_spec("f.cr", count: 20)
      root.randomize(Random::PCG32.new(seed))
      after_randomize1 = all_spec_descriptions(root)

      root = build_spec("f.cr", count: 20)
      root.randomize(Random::PCG32.new(seed))
      after_randomize2 = all_spec_descriptions(root)

      after_randomize1.should eq after_randomize2
    end
  end

  describe "#report" do
    it "should include parent's description" do
      root = FakeRootContext.new
      child = Spec::ExampleGroup.new(root, "child", "f.cr", 1, 10, false, nil)
      grand_child = Spec::ExampleGroup.new(child, "grand_child", "f.cr", 2, 9, false, nil)

      grand_child.report(:fail, "oops", "f.cr", 3, nil, nil)

      root.@results[:fail].first.description.should eq("child grand_child oops")
    end
  end
end
