require "spec"

describe "Array" do
  describe "empty" do
    it "is empty" do
      [].empty?.should be_true
    end

    it "has length 0" do
      [].length.should eq(0)
    end
  end
end
