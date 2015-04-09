require "spec"

describe "Range" do
  it "gets basic properties" do
    r = 1 .. 5
    r.begin.should eq(1)
    r.end.should eq(5)
    r.excludes_end?.should be_false

    r = 1 ... 5
    r.begin.should eq(1)
    r.end.should eq(5)
    r.excludes_end?.should be_true
  end

  it "includes?" do
    (1 .. 5).includes?(1).should be_true
    (1 .. 5).includes?(5).should be_true

    (1 ... 5).includes?(1).should be_true
    (1 ... 5).includes?(5).should be_false
  end

  it "does to_s" do
    (1...5).to_s.should eq("1...5")
    (1..5).to_s.should eq("1..5")
  end

  it "does inspect" do
    (1...5).inspect.should eq("1...5")
  end

  describe "each iterator" do
    it "does next with inclusive range" do
      a = 1..3
      iterator = a.each
      iterator.next.should eq(1)
      iterator.next.should eq(2)
      iterator.next.should eq(3)
      iterator.next.should be_a(Iterator::Stop)
    end

    it "does next with exclusive range" do
      r = 1...3
      iterator = r.each
      iterator.next.should eq(1)
      iterator.next.should eq(2)
      iterator.next.should be_a(Iterator::Stop)
    end

    it "cycles" do
      (1..3).cycle.take(8).join.should eq("12312312")
    end
  end
end
