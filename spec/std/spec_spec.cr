require "spec"

describe "Spec matchers" do
  describe "should be_truthy" do
    it "passes for true" do
      expect(true).to be_truthy
    end

    it "passes for some non-nil, non-false value" do
      expect(42).to be_truthy
    end
  end

  describe "should_not be_truthy" do
    it "passes for false" do
      expect(false).to_not be_truthy
    end

    it "passes for nil" do
      expect(nil).to_not be_truthy
    end
  end

  describe "should be_falsey" do
    it "passes for false" do
      expect(false).to be_falsey
    end

    it "passes for nil" do
      expect(nil).to be_falsey
    end
  end

  describe "should_not be_falsey" do
    it "passses for true" do
      expect(true).to_not be_falsey
    end

    it "passes for some non-nil, non-false value" do
      expect(42).to_not be_falsey
    end
  end

  describe "should contain" do
    it "passes when string includes? specified substring" do
      expect("hello world!").to contain("hello")
    end

    it "works with array" do
      expect([1, 2, 3, 5, 8]).to contain(5)
    end

    it "works with set" do
      expect([1, 2, 3, 5, 8].to_set).to contain(8)
    end

    it "works with range" do
      expect((50 .. 55)).to contain(53)
    end

    it "does not pass when string does not includes? specified substring" do
      expect_raises Spec::AssertionFailed, %{expected:   "hello world!"\nto include: "crystal"} do
        expect("hello world!").to contain("crystal")
      end
    end
  end

  describe "should_not contain" do
    it "passes when string does not includes? specified substring" do
      expect("hello world!").to_not contain("crystal")
    end

    it "does not pass when string does not includes? specified substring" do
      expect_raises Spec::AssertionFailed, %{expected: value "hello world!"\nto not include: "world"} do
        expect("hello world!").to_not contain("world")
      end
    end
  end

  context "should work as describe" do
    it "is true" do
      expect(true).to be_truthy
    end
  end
end
