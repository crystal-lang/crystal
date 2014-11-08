#!/usr/bin/env bin/crystal --run
require "spec"

describe "Enumerable" do
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

  describe "max_by" do
    assert { [-1, -2, -3].max_by { |x| -x }.should eq(-3) }
  end

  describe "minmax_by" do
    assert { [-1, -2, -3].minmax_by { |x| -x }.should eq({-1, -3}) }
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

  it "joins with io and block" do
    str = StringIO.new
    [1, 2, 3].join(", ", str) { |x, io| io << x + 1 }
    str.to_s.should eq("2, 3, 4")
  end
end
