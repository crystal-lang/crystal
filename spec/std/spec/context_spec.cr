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

      root.results_for(:fail).first.description.should eq("child grand_child oops")
    end
  end

  describe "#all_tags" do
    it "should include ancestor tags" do
      root = FakeRootContext.new
      child = Spec::ExampleGroup.new(root, "child", "f.cr", 1, 10, false, Set{"A"})
      grand_child = Spec::ExampleGroup.new(child, "grand_child", "f.cr", 2, 9, false, Set{"B"})
      example = Spec::Example.new(grand_child, "example", "f.cr", 3, 8, false, Set{"C"}, nil)
      other_group = Spec::ExampleGroup.new(root, "other_group", "f.cr", 11, 20, false, nil)

      child.all_tags.should eq(Set{"A"})
      grand_child.all_tags.should eq(Set{"A", "B"})
      example.all_tags.should eq(Set{"A", "B", "C"})
      other_group.all_tags.should be_empty
    end
  end
end
