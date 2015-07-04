require "spec"

describe "Enumerable" do
  describe "drop" do
    it "returns an array without the dropped elements" do
      [1, 2, 3, 4, 5, 6].drop(3).should eq [4, 5, 6]
    end

    it "returns an empty array when dropping more elements than array size" do
      [1, 2].drop(3).should eq [] of Int32
    end

    it "raises if count is negative" do
      expect_raises(ArgumentError) do
        [1, 2].drop(-1)
      end
    end
  end

  describe "all? with block" do
    it "returns true" do
      ["ant", "bear", "cat"].all? { |word| word.length >= 3 }.should be_true
    end

    it "returns false" do
      ["ant", "bear", "cat"].all? { |word| word.length >= 4 }.should be_false
    end
  end

  describe "all? without block" do
    it "returns true" do
      [15].all?.should be_true
    end

    it "returns false" do
      [nil, true, 99].all?.should be_false
    end
  end

  describe "find" do
    it "finds" do
      [1, 2, 3].find { |x| x > 2 }.should eq(3)
    end

    it "doesn't find" do
      [1, 2, 3].find { |x| x > 3 }.should be_nil
    end

    it "doesn't find with default value" do
      [1, 2, 3].find(-1) { |x| x > 3 }.should eq(-1)
    end
  end

  describe "inject" do
    assert { [1, 2, 3].inject { |memo, i| memo + i }.should eq(6) }
    assert { [1, 2, 3].inject(10) { |memo, i| memo + i }.should eq(16) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).inject { |memo, i| memo + i }
      end
    end
  end

  describe "min" do
    assert { [1, 2, 3].min.should eq(1) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).min
      end
    end
  end

  describe "max" do
    assert { [1, 2, 3].max.should eq(3) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).max
      end
    end
  end

  describe "minmax" do
    assert { [1, 2, 3].minmax.should eq({1, 3}) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).minmax
      end
    end
  end

  describe "min_by" do
    assert { [1, 2, 3].min_by { |x| -x }.should eq(3) }
  end

  describe "min_of" do
    assert { [1, 2, 3].min_of { |x| -x }.should eq(-3) }
  end

  describe "max_by" do
    assert { [-1, -2, -3].max_by { |x| -x }.should eq(-3) }
  end

  describe "max_of" do
    assert { [-1, -2, -3].max_of { |x| -x }.should eq(3) }
  end

  describe "minmax_by" do
    assert { [-1, -2, -3].minmax_by { |x| -x }.should eq({-1, -3}) }
  end

  describe "minmax_of" do
    assert { [-1, -2, -3].minmax_of { |x| -x }.should eq({1, 3}) }
  end

  describe "take" do
    assert { [-1, -2, -3].take(1).should eq([-1]) }
    assert { [-1, -2, -3].take(4).should eq([-1, -2, -3]) }
  end

  describe "first" do
    assert { [-1, -2, -3].first.should eq(-1) }
    assert { [-1, -2, -3].first(1).should eq([-1]) }
    assert { [-1, -2, -3].first(4).should eq([-1, -2, -3]) }
  end

  describe "one?" do
    assert { [1, 2, 2, 3].one? { |x| x == 1 }.should eq(true) }
    assert { [1, 2, 2, 3].one? { |x| x == 2 }.should eq(false) }
    assert { [1, 2, 2, 3].one? { |x| x == 0 }.should eq(false) }
  end

  describe "none?" do
    assert { [1, 2, 2, 3].none? { |x| x == 1 }.should eq(false) }
    assert { [1, 2, 2, 3].none? { |x| x == 0 }.should eq(true) }
  end

  describe "none? without block" do
    assert { [nil, false].none?.should be_true }
    assert { [nil, false, true].none?.should be_false }
  end

  describe "group_by" do
    assert { [1, 2, 2, 3].group_by { |x| x == 2 }.should eq({true => [2, 2], false => [1, 3]}) }
  end

  describe "partition" do
    assert { [1, 2, 2, 3].partition { |x| x == 2 }.should eq({[2, 2], [1, 3]}) }
  end

  describe "sum" do
    assert { ([] of Int32).sum.should eq(0) }
    assert { [1, 2, 3].sum.should eq(6) }
    assert { [1, 2, 3].sum(4).should eq(10) }
    assert { [1, 2, 3].sum(4.5).should eq(10.5) }
    assert { (1..3).sum { |x| x * 2 }.should eq(12) }
    assert { (1..3).sum(1.5) { |x| x * 2 }.should eq(13.5) }

    it "uses zero from type" do
      typeof([1, 2, 3].sum).should eq(Int32)
      typeof([1.5, 2.5, 3.5].sum).should eq(Float64)
      typeof([1, 2, 3].sum(&.to_f)).should eq(Float64)
    end
  end

  describe "compact map" do
    assert { Set { 1, nil, 2, nil, 3 }.compact_map { |x| x.try &.+(1) }.should eq([2, 3, 4]) }
  end

  describe "first" do
    it "gets first" do
      (1..3).first.should eq(1)
    end

    it "raises if enumerable empty" do
      expect_raises EmptyEnumerable do
        (1...1).first
      end
    end
  end

  describe "first?" do
    it "gets first?" do
      (1..3).first?.should eq(1)
    end

    it "returns nil if enumerable empty" do
      (1...1).first?.should be_nil
    end
  end

  describe "to_h" do
    it "for tuples" do
      hash = Tuple.new({:a, 1}, {:c, 2}).to_h
      hash.should be_a(Hash(Symbol, Int32))
      hash.should eq({a: 1, c: 2})
    end

    it "for array" do
      [[:a, :b], [:c, :d]].to_h.should eq({a: :b, c: :d})
    end
  end

  it "indexes by" do
    ["foo", "hello", "goodbye", "something"].index_by(&.length).should eq({
        3 => "foo",
        5 => "hello",
        7 => "goodbye",
        9 => "something",
      })
  end

  it "selects" do
    [1, 2, 3, 4].select(&.even?).should eq([2, 4])
  end

  it "rejects" do
    [1, 2, 3, 4].reject(&.even?).should eq([1, 3])
  end

  it "sorts" do
    {1, 2, 3, 1, 2}.sort.should eq([1, 1, 2, 2, 3])
  end

  it "sorts with block" do
    {1, 2, 3, 1, 2}.sort { |a, b| b <=> a }.should eq([3, 2, 2, 1, 1])
  end

  it "joins with separator and block" do
    str = [1, 2, 3].join(", ") { |x| x + 1 }
    str.should eq("2, 3, 4")
  end

  it "joins without separator and block" do
    str = [1, 2, 3].join { |x| x + 1 }
    str.should eq("234")
  end

  it "joins with io and block" do
    str = StringIO.new
    [1, 2, 3].join(", ", str) { |x, io| io << x + 1 }
    str.to_s.should eq("2, 3, 4")
  end

  describe "each_slice" do
    it "returns partial slices" do
      array = [] of Array(Int32)
      [1, 2, 3].each_slice(2) { |slice| array << slice }
      array.should eq([[1, 2], [3]])
    end

    it "returns full slices" do
      array = [] of Array(Int32)
      [1, 2, 3, 4].each_slice(2) { |slice| array << slice }
      array.should eq([[1, 2], [3, 4]])
    end

    it "returns each_slice iterator" do
      iter = [1, 2, 3, 4, 5].each_slice(2)
      iter.next.should eq([1, 2])
      iter.next.should eq([3, 4])
      iter.next.should eq([5])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq([1, 2])
    end
  end

  describe "each_cons" do
    it "returns running pairs" do
      array = [] of Array(Int32)
      [1, 2, 3, 4].each_cons(2) { |pair| array << pair }
      array.should eq([[1, 2], [2, 3], [3, 4]])
    end

    it "returns running triples" do
      array = [] of Array(Int32)
      [1, 2, 3, 4, 5].each_cons(3) { |triple| array << triple }
      array.should eq([[1, 2, 3], [2, 3, 4], [3, 4, 5]])
    end

    it "returns each_cons iterator" do
      iter = [1, 2, 3, 4, 5].each_cons(3)
      iter.next.should eq([1, 2, 3])
      iter.next.should eq([2, 3, 4])
      iter.next.should eq([3, 4, 5])
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq([1, 2, 3])
    end
  end

  it "gets each_with_index iterator" do
    iter = [1, 2].each_with_index
    iter.next.should eq({1, 0})
    iter.next.should eq({2, 1})
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq({1, 0})
  end

  it "gets each_with_object iterator" do
    iter = [1, 2].each_with_object("a")
    iter.next.should eq({1, "a"})
    iter.next.should eq({2, "a"})
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq({1, "a"})
  end
end
