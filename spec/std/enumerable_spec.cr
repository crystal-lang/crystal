require "spec"

describe "Enumerable" do
  describe "find" do
    it "finds" do
      expect([1, 2, 3].find { |x| x > 2 }).to eq(3)
    end

    it "doesn't find" do
      expect([1, 2, 3].find { |x| x > 3 }).to be_nil
    end

    it "doesn't find with default value" do
      expect([1, 2, 3].find(-1) { |x| x > 3 }).to eq(-1)
    end
  end

  describe "inject" do
    assert { expect([1, 2, 3].inject { |memo, i| memo + i }).to eq(6) }
    assert { expect([1, 2, 3].inject(10) { |memo, i| memo + i }).to eq(16) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).inject { |memo, i| memo + i }
      end
    end
  end

  describe "min" do
    assert { expect([1, 2, 3].min).to eq(1) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).min
      end
    end
  end

  describe "max" do
    assert { expect([1, 2, 3].max).to eq(3) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).max
      end
    end
  end

  describe "minmax" do
    assert { expect([1, 2, 3].minmax).to eq({1, 3}) }

    it "raises if empty" do
      expect_raises EmptyEnumerable do
        ([] of Int32).minmax
      end
    end
  end

  describe "min_by" do
    assert { expect([1, 2, 3].min_by { |x| -x }).to eq(3) }
  end

  describe "min_of" do
    assert { expect([1, 2, 3].min_of { |x| -x }).to eq(-3) }
  end

  describe "max_by" do
    assert { expect([-1, -2, -3].max_by { |x| -x }).to eq(-3) }
  end

  describe "max_of" do
    assert { expect([-1, -2, -3].max_of { |x| -x }).to eq(3) }
  end

  describe "minmax_by" do
    assert { expect([-1, -2, -3].minmax_by { |x| -x }).to eq({-1, -3}) }
  end

  describe "minmax_of" do
    assert { expect([-1, -2, -3].minmax_of { |x| -x }).to eq({1, 3}) }
  end

  describe "take" do
    assert { expect([-1, -2, -3].take(1)).to eq([-1]) }
    assert { expect([-1, -2, -3].take(4)).to eq([-1, -2, -3]) }
  end

  describe "first" do
    assert { expect([-1, -2, -3].first).to eq(-1) }
    assert { expect([-1, -2, -3].first(1)).to eq([-1]) }
    assert { expect([-1, -2, -3].first(4)).to eq([-1, -2, -3]) }
  end

  describe "one?" do
    assert { expect([1, 2, 2, 3].one? { |x| x == 1 }).to eq(true) }
    assert { expect([1, 2, 2, 3].one? { |x| x == 2 }).to eq(false) }
    assert { expect([1, 2, 2, 3].one? { |x| x == 0 }).to eq(false) }
  end

  describe "none?" do
    assert { expect([1, 2, 2, 3].none? { |x| x == 1 }).to eq(false) }
    assert { expect([1, 2, 2, 3].none? { |x| x == 0 }).to eq(true) }
  end

  describe "group_by" do
    assert { expect([1, 2, 2, 3].group_by { |x| x == 2 }).to eq({true => [2, 2], false => [1, 3]}) }
  end

  describe "partition" do
    assert { expect([1, 2, 2, 3].partition { |x| x == 2 }).to eq({[2, 2], [1, 3]}) }
  end

  describe "sum" do
    assert { expect(([] of Int32).sum).to eq(0) }
    assert { expect([1, 2, 3].sum).to eq(6) }
    assert { expect([1, 2, 3].sum(4)).to eq(10) }
    assert { expect([1, 2, 3].sum(4.5)).to eq(10.5) }
    assert { expect((1..3).sum { |x| x * 2 }).to eq(12) }
    assert { expect((1..3).sum(1.5) { |x| x * 2 }).to eq(13.5) }
  end

  describe "compact map" do
    assert { expect(Set { 1, nil, 2, nil, 3 }.compact_map { |x| x.try &.+(1) }).to eq([2, 3, 4]) }
  end

  describe "first" do
    it "gets first" do
      expect((1..3).first).to eq(1)
    end

    it "raises if enumerable empty" do
      expect_raises EmptyEnumerable do
        (1...1).first
      end
    end
  end

  describe "first?" do
    it "gets first?" do
      expect((1..3).first?).to eq(1)
    end

    it "returns nil if enumerable empty" do
      expect((1...1).first?).to be_nil
    end
  end

  describe "to_h" do
    it "for tuples" do
      hash = Tuple.new({:a, 1}, {:c, 2}).to_h
      expect(hash).to be_a(Hash(Symbol, Int32))
      expect(hash).to eq({a: 1, c: 2})
    end

    it "for array" do
      expect([[:a, :b], [:c, :d]].to_h).to eq({a: :b, c: :d})
    end
  end

  it "indexes by" do
    expect(["foo", "hello", "goodbye", "something"].index_by(&.length)).to eq({
        3 => "foo",
        5 => "hello",
        7 => "goodbye",
        9 => "something",
      })
  end

  it "selects" do
    expect([1, 2, 3, 4].select(&.even?)).to eq([2, 4])
  end

  it "rejects" do
    expect([1, 2, 3, 4].reject(&.even?)).to eq([1, 3])
  end

  it "joins with separator and block" do
    str = [1, 2, 3].join(", ") { |x| x + 1 }
    expect(str).to eq("2, 3, 4")
  end

  it "joins without separator and block" do
    str = [1, 2, 3].join { |x| x + 1 }
    expect(str).to eq("234")
  end

  it "joins with io and block" do
    str = StringIO.new
    [1, 2, 3].join(", ", str) { |x, io| io << x + 1 }
    expect(str.to_s).to eq("2, 3, 4")
  end

  describe "each_slice" do
    it "returns partial slices" do
      array = [] of Array(Int32)
      [1, 2, 3].each_slice(2) { |slice| array << slice }
      expect(array).to eq([[1, 2], [3]])
    end

    it "returns full slices" do
      array = [] of Array(Int32)
      [1, 2, 3, 4].each_slice(2) { |slice| array << slice }
      expect(array).to eq([[1, 2], [3, 4]])
    end
  end
end
