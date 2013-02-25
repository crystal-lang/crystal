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
      [1, 2, 3][3 .. 1].should eq([])
    end

    it "gets with start and count" do
      [1, 2, 3, 4, 5, 6][1, 3].should eq([2, 3, 4])
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
      [].empty?.should be_true
    end

    it "has length 0" do
      [].length.should eq(0)
    end
  end

  describe "==" do
    it "compare empty" do
      [].should eq([])
      [1].should_not eq([])
      [].should_not eq([1])
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
      a.index(4).should eq(-1)
    end

    it "performs with a block" do
      a = [1, 2, 3]
      a.index { |i| i > 1 }.should eq(1)
      a.index { |i| i > 3 }.should eq(-1)
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
      a = [1, 2, 3, 4]
      a.delete_at(4).should be_nil
      a.should eq([1, 2, 3, 4])
    end
  end
end
