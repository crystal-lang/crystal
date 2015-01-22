require "spec"

describe "Spec matchers" do
  describe "should be_truthy" do
    it "passes for true" do
      true.should be_truthy
    end

    it "passes for some non-nil, non-false value" do
      42.should be_truthy
    end
  end

  describe "should_not be_truthy" do
    it "passes for false" do
      false.should_not be_truthy
    end

    it "passes for nil" do
      nil.should_not be_truthy
    end
  end

  describe "should be_falsey" do
    it "passes for false" do
      false.should be_falsey
    end

    it "passes for nil" do
      nil.should be_falsey
    end
  end

  describe "should_not be_falsey" do
    it "passses for true" do
      true.should_not be_falsey
    end

    it "passes for some non-nil, non-false value" do
      42.should_not be_falsey
    end
  end

  context "should work as describe" do
    it "is true" do
      true.should be_truthy
    end
  end
end
