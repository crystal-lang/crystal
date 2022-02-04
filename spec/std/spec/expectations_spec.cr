require "spec"

describe "expectations" do
  describe "accept a custom failure message" do
    it { 1.should be < 3, "custom message!" }
    it do
      expect_raises(Spec::AssertionFailed, "custom message!") do
        1.should_not be < 3, "custom message!"
      end
    end
  end

  describe "be" do
    it { 1.should be < 3 }
    it { 2.should be <= 3 }
    it { 3.should be <= 3 }
    it { 3.should be >= 3 }
    it { 4.should be >= 3 }
    it { 5.should be > 3 }
  end

  describe "be" do
    it { "hello".should be "hello" }
    it do
      array = [1]
      array.should_not be [1]
    end
  end

  describe "be_a" do
    it { "Hello".should be_a(String) }
    it { 100_000.should_not be_a(String) }
    it { 100_000.should be_a(Int32) }
    it { "Hello".should_not be_a(Int32) }

    it "restricts type on should" do
      x = 1 || 'a'
      y = x.should be_a(Int32)
      typeof(x).should eq(Int32 | Char)
      typeof(y).should eq(Int32)
    end

    it "restricts type on should_not" do
      x = 1 || 'a'
      y = x.should_not be_a(Char)
      typeof(x).should eq(Int32 | Char)
      typeof(y).should eq(Int32)
    end
  end

  describe "be_close" do
    it { 8.5.should be_close(9, 0.5) }
    it { 7.5.should_not be_close(9, 0.5) }
  end

  describe "be_nil" do
    it { nil.should be_nil }
    it { "".should_not be_nil }
    it { 10.should_not be_nil }

    it "restricts type on should_not" do
      x = 1 || nil
      y = x.should_not be_nil
      typeof(x).should eq(Int32?)
      typeof(y).should eq(Int32)
    end
  end

  describe "be_falsey" do
    it { nil.should be_falsey }
    it { false.should be_falsey }
    it { true.should_not be_falsey }
    it { "crystal".should_not be_falsey }
  end

  describe "be_truthy" do
    it { true.should be_truthy }
    it { "crystal".should be_truthy }
    it { nil.should_not be_truthy }
    it { false.should_not be_truthy }
  end

  describe "be_false" do
    it { false.should be_false }
    it { nil.should_not be_false }
    it { true.should_not be_false }
    it { "crystal".should_not be_false }
  end

  describe "be_true" do
    it { true.should be_true }
    it { nil.should_not be_true }
    it { false.should_not be_true }
    it { "crystal".should_not be_true }
  end

  describe "contain" do
    it { [1, 2, 3].should contain(1) }
    it { [1, 2, 3].should contain(2) }
    it { [1, 2, 3].should contain(3) }
    it { [1, 2, 3].should_not contain(4) }
    it { "crystal".should contain("c") }
    it { "crystal".should contain("crys") }
    it { "crystal".should contain("crystal") }
    it { "crystal".should_not contain("o") }
    it { "crystal".should_not contain("world") }
  end

  describe "eq" do
    it { 10.should eq(10) }
    it { 10.should_not eq(1) }
  end

  describe "match" do
    it { "Crystal".should match(/Crystal/) }
    it { "Crystal".should match(/ysta/) }
    it { "Crystal".should_not match(/hello/) }
  end

  describe "start_with" do
    it { "1-2-3".should start_with("") }
    it { "1-2-3".should start_with("1") }
    it { "1-2-3".should start_with("1-") }
    it { "1-2-3".should start_with("1-2-3") }
    it { "1-2-3".should_not start_with("2-") }
    it { "1-2-3".should_not start_with("1-2-3-4") }
  end

  describe "end_with" do
    it { "1-2-3".should end_with("") }
    it { "1-2-3".should end_with("3") }
    it { "1-2-3".should end_with("-3") }
    it { "1-2-3".should end_with("1-2-3") }
    it { "1-2-3".should_not end_with("-2") }
    it { "1-2-3".should_not end_with("0-1-2-3") }
  end

  context "empty" do
    it { "".should be_empty }
    it { Array(String).new.should be_empty }
    it { Hash(String, String).new.should be_empty }
    it { "foo".should_not be_empty }
    it { ["foo", "bar"].should_not be_empty }
    it { {"foo" => "bar"}.should_not be_empty }
    it { {"foo", "bar"}.should_not be_empty }
  end

  describe "expect_raises" do
    it "pass if raises MyError" do
      expect_raises(Exception, "Ops") { raise Exception.new("Ops") }
    end
  end
end
