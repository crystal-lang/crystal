require "spec"

describe "Bool" do
  describe "!" do
    it { (!true).should be_false }
    it { (!false).should be_true }
  end

  describe "|" do
    it { (false | false).should be_false }
    it { (false | true).should be_true }
    it { (true | false).should be_true }
    it { (true | true).should be_true }
  end

  describe "&" do
    it { (false & false).should be_false }
    it { (false & true).should be_false }
    it { (true & false).should be_false }
    it { (true & true).should be_true }
  end

  describe "^" do
    it { (false ^ false).should be_false }
    it { (false ^ true).should be_true }
    it { (true ^ false).should be_true }
    it { (true ^ true).should be_false }
  end

  describe "hash" do
    it { true.hash.should_not eq(false.hash) }
  end

  describe "to_s" do
    it { true.to_s.should eq("true") }
    it { false.to_s.should eq("false") }
  end

  describe "clone" do
    it { true.clone.should be_true }
    it { false.clone.should be_false }
  end
end
