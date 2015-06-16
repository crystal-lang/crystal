require "spec"

describe "Stats" do
  it "mean" do
    Math.mean([1, 3.5, 9]).should eq(4.5)
    Math.mean({1, 3.5, 9}).should eq(4.5)
  end
end
