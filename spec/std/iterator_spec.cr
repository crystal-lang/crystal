require "spec"
require "iterator"

describe Iterator do
  describe "ArrayIterator" do
    it "does next" do
      a = [1, 2, 3]
      iterator = a.iterator
      expect(iterator.next).to eq(1)
      expect(iterator.next).to eq(2)
      expect(iterator.next).to eq(3)
      expect(iterator.next).to eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "RangeIterator" do
    it "does next with inclusive range" do
      a = 1..3
      iterator = a.iterator
      expect(iterator.next).to eq(1)
      expect(iterator.next).to eq(2)
      expect(iterator.next).to eq(3)
      expect(iterator.next).to eq(Iterator::Stop::INSTANCE)
    end

    it "does next with exclusive range" do
      r = 1...3
      iterator = r.iterator
      expect(iterator.next).to eq(1)
      expect(iterator.next).to eq(2)
      expect(iterator.next).to eq(Iterator::Stop::INSTANCE)
    end
  end

  describe "map" do
    it "does map with Range iterator" do
      expect((1..3).iterator.map { |x| x * 2 }.to_a).to eq([2, 4, 6])
    end
  end

  describe "select" do
    it "does select with Range iterator" do
      expect((1..3).iterator.select { |x| x >= 2 }.to_a).to eq([2, 3])
    end
  end

  describe "reject" do
    it "does reject with Range iterator" do
      expect((1..3).iterator.reject { |x| x >= 2 }.to_a).to eq([1])
    end
  end

  describe "take" do
    it "does take with Range iterator" do
      expect((1..3).iterator.take(2).to_a).to eq([1, 2])
    end

    it "does take with more than available" do
      expect((1..3).iterator.take(10).to_a).to eq([1, 2, 3])
    end
  end

  describe "skip" do
    it "does skip with Range iterator" do
      expect((1..3).iterator.skip(2).to_a).to eq([3])
    end
  end

  describe "zip" do
    it "does skip with Range iterator" do
      r1 = (1..3).iterator
      r2 = (4..6).iterator
      expect(r1.zip(r2).to_a).to eq([{1, 4}, {2, 5}, {3, 6}])
    end
  end

  describe "cycle" do
    it "does cycle from range" do
      expect((1..3).iterator.cycle.take(10).to_a).to eq([1, 2, 3, 1, 2, 3, 1, 2, 3, 1])
    end

    it "cycles an empty array" do
      ary = [] of Int32
      values = ary.iterator.cycle.to_a
      expect(values.empty?).to be_true
    end
  end

  describe "with_index" do
    it "does with_index from range" do
      expect((1..3).iterator.with_index.to_a).to eq([{1, 0}, {2, 1}, {3, 2}])
    end
  end

  it "combines many iterators" do
    expect((1..100).iterator
                   .select { |x| 50 <= x < 60 }
                   .map { |x| x * 2 }
                   .take(3)
                   .to_a
                   ).to eq([100, 102, 104])
  end
end
