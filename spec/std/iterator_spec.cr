require "spec"
require "iterator"

describe Iterator do
  describe "map" do
    it "does map with Range iterator" do
      (1..3).each.map { |x| x * 2 }.to_a.should eq([2, 4, 6])
    end
  end

  describe "select" do
    it "does select with Range iterator" do
      (1..3).each.select { |x| x >= 2 }.to_a.should eq([2, 3])
    end
  end

  describe "reject" do
    it "does reject with Range iterator" do
      (1..3).each.reject { |x| x >= 2 }.to_a.should eq([1])
    end
  end

  describe "take" do
    it "does take with Range iterator" do
      (1..3).each.take(2).to_a.should eq([1, 2])
    end

    it "does take with more than available" do
      (1..3).each.take(10).to_a.should eq([1, 2, 3])
    end
  end

  describe "skip" do
    it "does skip with Range iterator" do
      (1..3).each.skip(2).to_a.should eq([3])
    end
  end

  describe "zip" do
    it "does skip with Range iterator" do
      r1 = (1..3).each
      r2 = (4..6).each
      r1.zip(r2).to_a.should eq([{1, 4}, {2, 5}, {3, 6}])
    end
  end

  describe "cycle" do
    it "does cycle from range" do
      (1..3).each.cycle.take(10).to_a.should eq([1, 2, 3, 1, 2, 3, 1, 2, 3, 1])
    end

    it "cycles an empty array" do
      ary = [] of Int32
      values = ary.each.cycle.to_a
      values.empty?.should be_true
    end
  end

  describe "with_index" do
    it "does with_index from range" do
      (1..3).each.with_index.to_a.should eq([{1, 0}, {2, 1}, {3, 2}])
    end
  end

  it "combines many iterators" do
    (1..100).each
            .select { |x| 50 <= x < 60 }
            .map { |x| x * 2 }
            .take(3)
            .to_a
            .should eq([100, 102, 104])
  end
end
