#!/usr/bin/env bin/crystal -run
require "spec"

describe "Array" do
  describe "[]" do
    it "gets on positive index" do
      [1, 2, 3][1].should eq(2)
    end

    it "gets on negative index" do
      [1, 2, 3][-1].should eq(3)
    end

    it "gets on inclusive range" do
      [1, 2, 3, 4, 5, 6][1 .. 4].should eq([2, 3, 4, 5])
    end

    it "gets on inclusive range with negative indices" do
      [1, 2, 3, 4, 5, 6][-5 .. -2].should eq([2, 3, 4, 5])
    end

    it "gets on exclusive range" do
      [1, 2, 3, 4, 5, 6][1 ... 4].should eq([2, 3, 4])
    end

    it "gets on exclusive range with negative indices" do
      [1, 2, 3, 4, 5, 6][-5 ... -2].should eq([2, 3, 4])
    end

    it "gets on empty range" do
      [1, 2, 3][3 .. 1].should eq([] of Int32)
    end

    it "gets with start and count" do
      [1, 2, 3, 4, 5, 6][1, 3].should eq([2, 3, 4])
    end

    it "gets nilable" do
      [1, 2, 3][2]?.should eq(3)
      [1, 2, 3][3]?.should be_nil
    end
  end

  describe "[]=" do
    it "sets on positive index" do
      a = [1, 2, 3]
      a[1] = 4
      a[1].should eq(4)
    end

    it "sets on negative index" do
      a = [1, 2, 3]
      a[-1] = 4
      a[2].should eq(4)
    end
  end

  describe "empty" do
    it "is empty" do
      ([] of Int32).empty?.should be_true
    end

    it "has length 0" do
      ([] of Int32).length.should eq(0)
    end
  end

  describe "==" do
    it "compare empty" do
      ([] of Int32).should eq([] of Int32)
      [1].should_not eq([] of Int32)
      ([] of Int32).should_not eq([1])
    end

    it "compare elements" do
      [1, 2, 3].should eq([1, 2, 3])
      [1, 2, 3].should_not eq([3, 2, 1])
    end
  end

  describe "inspect" do
    assert { [1, 2, 3].inspect.should eq("[1, 2, 3]") }
  end

  describe "+" do
    assert do
      a = [1, 2, 3]
      b = [4, 5]
      c = a + b
      c.length.should eq(5)
      0.upto(4) { |i| c[i].should eq(i + 1) }
    end
  end

  describe "concat" do
    assert do
      a = [1, 2, 3]
      a.concat([4, 5, 6])
      a.should eq([1, 2, 3, 4, 5, 6])
    end
  end

  describe "index" do
    it "performs without a block" do
      a = [1, 2, 3]
      a.index(3).should eq(2)
      a.index(4).should be_nil
    end

    it "performs with a block" do
      a = [1, 2, 3]
      a.index { |i| i > 1 }.should eq(1)
      a.index { |i| i > 3 }.should be_nil
    end
  end

  describe "delete_at" do
    it "deletes positive index" do
      a = [1, 2, 3, 4]
      a.delete_at(1).should eq(2)
      a.should eq([1, 3, 4])
    end

    it "deletes negative index" do
      a = [1, 2, 3, 4]
      a.delete_at(-3).should eq(2)
      a.should eq([1, 3, 4])
    end

    it "deletes out of bounds" do
      begin
        a = [1, 2, 3, 4]
        a.delete_at(4)
        fail "Expected to raise Array::IndexOutOfBounds"
      rescue Array::IndexOutOfBounds
      end
    end
  end

  describe "delete" do
    it "deletes many" do
      a = [1, 2, 3, 1, 2, 3]
      a.delete(2).should be_true
      a.should eq([1, 3, 1, 3])
    end

    it "delete not found" do
      a = [1, 2]
      a.delete(4).should be_false
      a.should eq([1, 2])
    end
  end

  describe "delete_if" do
    it "deletes many" do
      a = [1, 2, 3, 1, 2, 3]
      a.delete_if { |i| i > 2 }
      a.should eq([1, 2, 1, 2])
    end
  end

  describe "&" do
    assert { ([1, 2, 3] & [3, 2, 4]).should eq([2, 3]) }
  end

  describe "|" do
    assert { ([1, 2, 3] | [5, 3, 2, 4]).should eq([1, 2, 3, 5, 4]) }
  end

  describe "-" do
    assert { ([1, 2, 3, 4, 5] - [4, 2]).should eq([1, 3, 5]) }
  end

  describe "clear" do
    assert do
      a = [1, 2, 3]
      a.clear
      a.should eq([] of Int32)
    end
  end

  describe "compact" do
    assert do
      a = [1, nil, 2, nil, 3]
      b = a.compact.should eq([1, 2, 3])
      a.should eq([1, nil, 2, nil, 3])
    end
  end

  describe "compact!" do
    it "returns true if removed" do
      a = [1, nil, 2, nil, 3]
      b = a.compact!.should be_true
      a.should eq([1, 2, 3])
    end

    it "returns false if not removed" do
      a = [1]
      b = a.compact!.should be_false
      a.should eq([1])
    end
  end

  # describe "flatten" do
  #   assert do
  #     a = [[1, 2], 3, [4, [5, 6]]]
  #     a.flatten([] of Int32).should eq([1, 2, 3, 4, 5, 6])
  #     a.should eq([[1, 2], 3, [4, [5, 6]]])
  #   end
  # end

  describe "map" do
    assert do
      a = [1, 2, 3]
      a.map { |x| x * 2 }.should eq([2, 4, 6])
      a.should eq([1, 2, 3])
    end
  end

  describe "map!" do
    assert do
      a = [1, 2, 3]
      a.map! { |x| x * 2 }
      a.should eq([2, 4, 6])
    end
  end

  describe "unshift" do
    assert do
      a = [2, 3]
      expected = [1, 2, 3]
      a.unshift(1).should eq(expected)
      a.should eq(expected)
    end
  end

  describe "insert" do
    it "inserts with positive index" do
      a = [1, 3, 4]
      expected = [1, 2, 3, 4]
      a.insert(1, 2).should eq(expected)
      a.should eq(expected)
    end

    it "inserts with negative index" do
      a = [1, 3, 4]
      expected = [1, 2, 3, 4]
      a.insert(-2, 2).should eq(expected)
      a.should eq(expected)
    end
  end

  describe "reverse" do
    assert do
      a = [1, 2, 3]
      a.reverse.should eq([3, 2, 1])
      a.should eq([1, 2, 3])
    end
  end

  describe "reverse!" do
    assert do
      a = [1, 2, 3, 4, 5]
      a.reverse!
      a.should eq([5, 4, 3, 2, 1])
    end
  end

  describe "uniq!" do
    assert do
      a = [1, 2, 2, 3, 1, 4, 5, 3]
      a.uniq!
      a.should eq([1, 2, 3, 4, 5])
    end

    assert do
      a = [-1, 1, 0, 2, -2]
      a.uniq! { |x| x.abs }
      a.should eq([-1, 0, 2])
    end

    assert do
      a = [1, 2, 3]
      a.uniq! { true }
      a.should eq([1])
    end
  end

  it "raises if out of bounds" do
    begin
      [1, 2, 3][4]
      fail "Expected [] to raise"
    rescue Array::IndexOutOfBounds
    end
  end

  it "has hash" do
    a = [1, 2, [3]]
    b = [1, 2, [3]]
    a.hash.should eq(b.hash)
  end

  describe "pop" do
    it "pops when non empty" do
      a = [1, 2, 3]
      a.pop.should eq(3)
      a.should eq([1, 2])
    end

    it "raises when empty" do
      begin
        ([] of Int32).pop
        fail "expected to raise Array::IndexOutOfBounds"
      rescue Array::IndexOutOfBounds
      end
    end
  end

  describe "shift" do
    it "shifts when non empty" do
      a = [1, 2, 3]
      a.shift.should eq(1)
      a.should eq([2, 3])
    end

    it "raises when empty" do
      begin
        ([] of Int32).shift
        fail "expected to raise Array::IndexOutOfBounds"
      rescue Array::IndexOutOfBounds
      end
    end
  end

  describe "first" do
    it "gets first when non empty" do
      a = [1, 2, 3]
      a.first.should eq(1)
    end

    it "raises when empty" do
      begin
        ([] of Int32).first
        fail "expected to raise Array::IndexOutOfBounds"
      rescue Array::IndexOutOfBounds
      end
    end
  end

  describe "last" do
    it "gets last when non empty" do
      a = [1, 2, 3]
      a.last.should eq(3)
    end

    it "raises when empty" do
      begin
        ([] of Int32).last
        fail "expected to raise Array::IndexOutOfBounds"
      rescue Array::IndexOutOfBounds
      end
    end
  end
end
