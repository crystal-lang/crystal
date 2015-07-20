require "spec"

describe "Range" do
  it "initialized with new method" do
    Range.new(1, 10).should eq(1..10)
    Range.new(1, 10, false).should eq(1..10)
    Range.new(1, 10, true).should eq(1...10)
  end

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

  it "is empty with .. and begin > end" do
    (1..0).to_a.empty?.should be_true
  end

  it "is empty with ... and begin > end" do
    (1...0).to_a.empty?.should be_true
  end

  it "is not empty with .. and begin == end" do
    (1..1).to_a.should eq([1])
  end

  it "is not empty with ... and begin.succ == end" do
    (1...2).to_a.should eq([1])
  end

  describe "each iterator" do
    it "does next with inclusive range" do
      a = 1..3
      iter = a.each
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does next with exclusive range" do
      r = 1...3
      iter = r.each
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "cycles" do
      (1..3).cycle.take(8).join.should eq("12312312")
    end

    it "is empty with .. and begin > end" do
      (1..0).each.to_a.empty?.should be_true
    end

    it "is empty with ... and begin > end" do
      (1...0).each.to_a.empty?.should be_true
    end

    it "is not empty with .. and begin == end" do
      (1..1).each.to_a.should eq([1])
    end

    it "is not empty with ... and begin.succ == end" do
      (1...2).each.to_a.should eq([1])
    end
  end

  describe "step iterator" do
    it "does next with inclusive range" do
      a = 1..5
      iter = a.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should eq(5)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does next with exclusive range" do
      a = 1...5
      iter = a.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does next with exclusive range (2)" do
      a = 1...6
      iter = a.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should eq(5)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "is empty with .. and begin > end" do
      (1..0).step(1).to_a.empty?.should be_true
    end

    it "is empty with ... and begin > end" do
      (1...0).step(1).to_a.empty?.should be_true
    end

    it "is not empty with .. and begin == end" do
      (1..1).step(1).to_a.should eq([1])
    end

    it "is not empty with ... and begin.succ == end" do
      (1...2).step(1).to_a.should eq([1])
    end
  end
end
