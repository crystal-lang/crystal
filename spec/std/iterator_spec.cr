require "spec"
require "iterator"

describe Iterator do
  describe "Iterator.of" do
    it "creates singleton" do
      iter = Iterator.of(42)
      iter.first(3).to_a.should eq([42, 42, 42])
    end

    it "creates singleton from block" do
      a = 0
      iter = Iterator.of { a += 1 }
      iter.first(3).to_a.should eq([1, 2, 3])
    end

    it "creates singleton from block can call Iterator.stop" do
      a = 0
      iter = Iterator.of do
        if a >= 5
          Iterator.stop
        else
          a += 1
        end
      end
      iter.should be_a(Iterator(Int32))
      iter.first(10).to_a.should eq([1, 2, 3, 4, 5])
    end
  end

  describe "compact_map" do
    it "applies the function and removes nil values" do
      iter = (1..3).each.compact_map { |e| e.odd? ? e : nil }
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "sums after compact_map to_a" do
      (1..3).each.compact_map { |e| e.odd? ? e : nil }.to_a.sum.should eq(4)
    end
  end

  describe "chain" do
    it "chains" do
      iter = (1..2).each.chain(('a'..'b').each)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq('a')
      iter.next.should eq('b')
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)

      iter.rewind
      iter.to_a.should eq([1, 2, 'a', 'b'])
    end
  end

  describe "compact_map" do
    it "does not return nil values" do
      iter = [1, nil, 2, nil].each.compact_map { |e| e.try &.*(2) }
      iter.next.should eq 2
      iter.next.should eq 4
      iter.next.should be_a(Iterator::Stop)
    end
  end

  describe "cons" do
    it "conses" do
      iter = (1..5).each.cons(3)
      iter.next.should eq([1, 2, 3])
      iter.next.should eq([2, 3, 4])
      iter.next.should eq([3, 4, 5])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq([1, 2, 3])
    end
  end

  describe "cycle" do
    it "does cycle from range" do
      iter = (1..3).each.cycle
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should eq(1)
      iter.next.should eq(2)

      iter.rewind
      iter.next.should eq(1)
    end

    it "cycles an empty array" do
      ary = [] of Int32
      values = ary.each.cycle.to_a
      values.empty?.should be_true
    end

    it "cycles N times" do
      iter = (1..2).each.cycle(2)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does not cycle provided 0" do
      iter = (1..2).each.cycle(0)
      iter.next.should be_a(Iterator::Stop)
    end

    it "does not cycle provided a negative size" do
      iter = (1..2).each.cycle(-1)
      iter.next.should be_a(Iterator::Stop)
    end
  end

  describe "each" do
    it "yields the individual elements to the block" do
      iter = ["a", "b", "c"].each
      concatinated = ""
      iter.each { |e| concatinated += e }.should be_nil
      concatinated.should eq "abc"
    end
  end

  describe "each_slice" do
    it "gets all the slices of the size n" do
      iter = (1..9).each.each_slice(3)
      iter.next.should eq [1, 2, 3]
      iter.next.should eq [4, 5, 6]
      iter.next.should eq [7, 8, 9]
      iter.next.should be_a Iterator::Stop
    end

    it "also works if it does not add up" do
      iter = (1..4).each.each_slice(3)
      iter.next.should eq [1, 2, 3]
      iter.next.should eq [4]
      iter.next.should be_a Iterator::Stop
    end

    it "returns each_slice iterator with reuse = true" do
      iter = (1..5).each.each_slice(2, reuse: true)

      a = iter.next
      a.should eq([1, 2])

      b = iter.next
      b.should eq([3, 4])
      b.should be(a)
    end

    it "returns each_slice iterator with reuse = array" do
      reuse = [] of Int32
      iter = (1..5).each.each_slice(2, reuse: reuse)

      a = iter.next
      a.should eq([1, 2])
      a.should be(reuse)

      b = iter.next
      b.should eq([3, 4])
      b.should be(reuse)
    end
  end

  describe "in_groups_of" do
    it "creats groups of one" do
      iter = (1..3).each.in_groups_of(1)
      iter.next.should eq([1])
      iter.next.should eq([2])
      iter.next.should eq([3])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq [1]
    end

    it "creats a group of two" do
      iter = (1..3).each.in_groups_of(2)
      iter.next.should eq([1, 2])
      iter.next.should eq([3, nil])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq [1, 2]
    end

    it "fills up with the fill up argument" do
      iter = (1..3).each.in_groups_of(2, 'z')
      iter.next.should eq([1, 2])
      iter.next.should eq([3, 'z'])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq [1, 2]
    end

    it "raises argument error if size is less than 0" do
      expect_raises ArgumentError, "Size must be positive" do
        [1, 2, 3].each.in_groups_of(0)
      end
    end

    it "still works with other iterator methods like to_a" do
      iter = (1..3).each.in_groups_of(2, 'z')
      iter.to_a.should eq [[1, 2], [3, 'z']]
    end

    it "creats a group of two with reuse = true" do
      iter = (1..3).each.in_groups_of(2, reuse: true)

      a = iter.next
      a.should eq([1, 2])

      b = iter.next
      b.should eq([3, nil])
      b.should be(a)

      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq [1, 2]
    end
  end

  describe "map" do
    it "does map with Range iterator" do
      iter = (1..3).each.map &.*(2)
      iter.next.should eq(2)
      iter.next.should eq(4)
      iter.next.should eq(6)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(2)
    end
  end

  describe "reject" do
    it "does reject with Range iterator" do
      iter = (1..3).each.reject &.>=(2)
      iter.next.should eq(1)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end
  end

  describe "select" do
    it "does select with Range iterator" do
      iter = (1..3).each.select &.>=(2)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(2)
    end
  end

  describe "skip" do
    it "does skip with Range iterator" do
      iter = (1..3).each.skip(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(3)
    end

    it "is cool to skip 0 elements" do
      (1..3).each.skip(0).to_a.should eq [1, 2, 3]
    end

    it "raises ArgumentError if negative size is provided" do
      expect_raises(ArgumentError) do
        (1..3).each.skip(-1)
      end
    end
  end

  describe "skip_while" do
    it "does skip_while with an array" do
      iter = [1, 2, 3, 4, 0].each.skip_while { |i| i < 3 }
      iter.next.should eq(3)
      iter.next.should eq(4)
      iter.next.should eq(0)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(3)
    end

    it "can skip everything" do
      iter = (1..3).each.skip_while { true }
      iter.to_a.should eq [] of Int32
    end

    it "returns the full array if the condition is false for the first item" do
      iter = (1..2).each.skip_while { false }
      iter.to_a.should eq [1, 2]
    end

    it "only calls the block as much as needed" do
      called = 0
      iter = (1..5).each.skip_while do |i|
        called += 1
        i < 3
      end
      5.times { iter.next }
      called.should eq 3
    end
  end

  describe "slice" do
    it "slices" do
      iter = (1..8).each.slice(3)
      iter.next.should eq([1, 2, 3])
      iter.next.should eq([4, 5, 6])
      iter.next.should eq([7, 8])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq([1, 2, 3])
    end
  end

  describe "step" do
    it "returns every element" do
      iter = (1..3).each.step(1)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)
    end

    it "returns every other element" do
      iter = (1..5).each.step(2)
      iter.next.should eq(1)
      iter.next.should eq(3)
      iter.next.should eq(5)
      iter.next.should be_a(Iterator::Stop)
    end

    it "returns every third element" do
      iter = (1..12).each.step(3)
      iter.next.should eq(1)
      iter.next.should eq(4)
      iter.next.should eq(7)
      iter.next.should eq(10)
      iter.next.should be_a(Iterator::Stop)
    end

    it "raises with nonsensical steps" do
      expect_raises(ArgumentError) do
        (1..2).each.step(0)
      end

      expect_raises(ArgumentError) do
        (1..2).each.step(-1)
      end
    end
  end

  describe "first" do
    it "does first with Range iterator" do
      iter = (1..3).each.first(2)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does first with more than available" do
      (1..3).each.first(10).to_a.should eq([1, 2, 3])
    end

    it "is cool to first 0 elements" do
      iter = (1..3).each.first(0)
      iter.next.should be_a Iterator::Stop
    end

    it "raises ArgumentError if negative size is provided" do
      expect_raises(ArgumentError) do
        (1..3).each.first(-1)
      end
    end
  end

  describe "take_while" do
    it "does take_while with Range iterator" do
      iter = (1..5).each.take_while { |i| i < 3 }
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "does take_while with more than available" do
      (1..3).each.take_while { true }.to_a.should eq([1, 2, 3])
    end

    it "only calls the block as much as needed" do
      called = 0
      iter = (1..5).each.take_while do |i|
        called += 1
        i < 3
      end
      5.times { iter.next }
      called.should eq 3
    end
  end

  describe "tap" do
    it "taps" do
      a = 0

      iter = (1..3).each.tap { |x| a += x }
      iter.next.should eq(1)
      a.should eq(1)

      iter.next.should eq(2)
      a.should eq(3)

      iter.next.should eq(3)
      a.should eq(6)

      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end
  end

  describe "uniq" do
    it "without block" do
      iter = (1..8).each.map { |x| x % 3 }.uniq
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(0)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "with block" do
      iter = (1..8).each.uniq { |x| (x % 3).to_s }
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end
  end

  describe "with_index" do
    it "does with_index from range" do
      iter = (1..3).each.with_index
      iter.next.should eq({1, 0})
      iter.next.should eq({2, 1})
      iter.next.should eq({3, 2})
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq({1, 0})
    end

    it "does with_index with offset from range" do
      iter = (1..3).each.with_index(10)
      iter.next.should eq({1, 10})
      iter.next.should eq({2, 11})
      iter.next.should eq({3, 12})
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq({1, 10})
    end

    it "does with_index from range, with block" do
      tuples = [] of {Int32, Int32}
      (1..3).each.with_index do |value, index|
        tuples << {value, index}
      end
      tuples.should eq([{1, 0}, {2, 1}, {3, 2}])
    end

    it "does with_index from range, with block with offset" do
      tuples = [] of {Int32, Int32}
      (1..3).each.with_index(10) do |value, index|
        tuples << {value, index}
      end
      tuples.should eq([{1, 10}, {2, 11}, {3, 12}])
    end
  end

  describe "with object" do
    it "does with object" do
      iter = (1..3).each.with_object("a")
      iter.next.should eq({1, "a"})
      iter.next.should eq({2, "a"})
      iter.next.should eq({3, "a"})
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq({1, "a"})
    end
  end

  describe "zip" do
    it "does skip with Range iterator" do
      r1 = (1..3).each
      r2 = ('a'..'c').each
      iter = r1.zip(r2)
      iter.next.should eq({1, 'a'})
      iter.next.should eq({2, 'b'})
      iter.next.should eq({3, 'c'})
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq({1, 'a'})

      iter.rewind
      iter.to_a.should eq([{1, 'a'}, {2, 'b'}, {3, 'c'}])
    end
  end

  describe "integreation" do
    it "combines many iterators" do
      (1..100).each
              .select { |x| 50 <= x < 60 }
              .map { |x| x * 2 }
              .first(3)
              .to_a
              .should eq([100, 102, 104])
    end
  end

  describe "flatten" do
    it "flattens an iterator of mixed-type iterators" do
      iter = [(1..2).each, ('a'..'b').each, {:c => 3}.each].each.flatten

      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq('a')
      iter.next.should eq('b')
      iter.next.should eq({:c, 3})

      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)

      iter.rewind
      iter.to_a.should eq([1, 2, 'a', 'b', {:c, 3}])
    end

    it "flattens an iterator of mixed-type elements and iterators" do
      iter = [(1..2).each, 'a'].each.flatten

      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq('a')

      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)

      iter.rewind
      iter.to_a.should eq([1, 2, 'a'])
    end

    it "flattens an iterator of mixed-type elements and iterators and iterators of iterators" do
      iter = [(1..2).each, [['a', 'b'].each].each, "foo"].each.flatten

      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq('a')
      iter.next.should eq('b')
      iter.next.should eq("foo")

      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)

      iter.rewind
      iter.to_a.should eq([1, 2, 'a', 'b', "foo"])
    end

    it "flattens deeply-nested and mixed type iterators" do
      iter = [[[1], 2], [3, [[4, 5], 6], 7], "a"].each.flatten

      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should eq(4)
      iter.next.should eq(5)
      iter.next.should eq(6)
      iter.next.should eq(7)
      iter.next.should eq("a")

      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)

      iter.rewind
      iter.to_a.should eq([1, 2, 3, 4, 5, 6, 7, "a"])
    end

    it "flattens a variety of edge cases" do
      ([] of Nil).each.flatten.to_a.should eq([] of Nil)
      ['a'].each.flatten.to_a.should eq(['a'])
      [[[[[["hi"]]]]]].each.flatten.to_a.should eq(["hi"])
    end

    it "flattens a deeply-nested iterables and arrays (#3703)" do
      iter = [[1, {2, 3}, 4], [{5 => 6}, 7]].each.flatten

      iter.next.should eq(1)
      iter.next.should eq({2, 3})
      iter.next.should eq(4)
      iter.next.should eq({5 => 6})
      iter.next.should eq(7)
      iter.next.should be_a(Iterator::Stop)
    end

    it "return iterator itself by rewind" do
      iter = [1, [2, 3], 4].each.flatten

      iter.to_a.should eq([1, 2, 3, 4])
      iter.rewind.to_a.should eq([1, 2, 3, 4])
    end
  end

  describe "#flat_map" do
    it "flattens returned arrays" do
      iter = [1, 2, 3].each.flat_map { |x| [x, x] }

      iter.next.should eq(1)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should eq(3)

      iter.rewind.to_a.should eq([1, 1, 2, 2, 3, 3])
    end

    it "flattens returned items" do
      iter = [1, 2, 3].each.flat_map { |x| x }

      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)

      iter.rewind.to_a.should eq([1, 2, 3])
    end

    it "flattens returned iterators" do
      iter = [1, 2, 3].each.flat_map { |x| [x, x].each }

      iter.next.should eq(1)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should eq(3)

      iter.rewind.to_a.should eq([1, 1, 2, 2, 3, 3])
    end

    it "flattens returned values" do
      iter = [1, 2, 3].each.flat_map do |x|
        case x
        when 1
          x
        when 2
          [x, x]
        else
          [x, x].each
        end
      end

      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should eq(3)

      iter.rewind.to_a.should eq([1, 2, 2, 3, 3])
    end
  end
end
