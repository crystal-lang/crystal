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

  describe "should contain" do
    it "passes when string includes? specified substring" do
      "hello world!".should contain("hello")
    end

    it "works with array" do
      [1, 2, 3, 5, 8].should contain(5)
    end

    it "works with set" do
      [1, 2, 3, 5, 8].to_set.should contain(8)
    end

    it "works with range" do
      (50 .. 55).should contain(53)
    end

    it "does not pass when string does not includes? specified substring" do
      expect_raises Spec::AssertionFailed, %{expected:   "hello world!"\nto include: "crystal"} do
        "hello world!".should contain("crystal")
      end
    end
  end

  describe "should_not contain" do
    it "passes when string does not includes? specified substring" do
      "hello world!".should_not contain("crystal")
    end

    it "does not pass when string does not includes? specified substring" do
      expect_raises Spec::AssertionFailed, %{expected: value "hello world!"\nto not include: "world"} do
        "hello world!".should_not contain("world")
      end
    end
  end

  context "should work like describe" do
    it "is true" do
      true.should be_truthy
    end
  end
end

describe "before and after hooks" do
  thing = 0

  before_each do
    thing += 2
  end

  after_each do
    thing -= 1
  end

  it "increments the variable by 2 before" do
    thing.should eq(2)
  end

  it "decrements the variable by 1 after" do
    thing.should eq(3)
  end
end
