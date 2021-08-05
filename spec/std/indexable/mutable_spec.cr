require "spec"

private class SafeIndexableMutable
  include Indexable::Mutable(Int32)

  getter size

  @values : Array(Tuple(Int32))

  def initialize(@size : Int32, *, offset = 0)
    @values = Array.new(size) { |i| {i + offset} }
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    @values[i][0]
  end

  def unsafe_put(i, value : Int32)
    raise IndexError.new unless 0 <= i < size
    @values[i] = {value}
  end
end

private class Foo
end

private class SafeIndexableMutableFoo
  include Indexable::Mutable(Foo)

  getter size

  @values : Array(Tuple(Foo))

  def initialize(@size : Int32)
    @values = Array.new(size) { {Foo.new} }
  end

  def unsafe_fetch(i)
    raise IndexError.new unless 0 <= i < size
    @values[i][0]
  end

  def unsafe_put(i, value : Foo)
    raise IndexError.new unless 0 <= i < size
    @values[i] = {value}
  end
end

describe Indexable::Mutable do
  # General note: code that tests `#method!` must not rely on the results of
  # `#method`, as otherwise those tests would trivially pass if the latter were
  # implemented as `to_a.method!`

  describe "#[]=" do
    it "sets the value at the given index" do
      coll = SafeIndexableMutable.new(5)
      (coll[2] = 123).should eq(123)
      coll[2].should eq(123)

      coll = SafeIndexableMutableFoo.new(5)
      foo = Foo.new
      (coll[2] = foo).should be(foo)
      coll[2].should be(foo)
    end

    it "wraps negative indices" do
      coll = SafeIndexableMutable.new(5)
      (coll[-2] = 123).should eq(123)
      coll[3].should eq(123)

      (coll[-5] = 456).should eq(456)
      coll[0].should eq(456)
    end

    it "raises on out-of-bound indices" do
      expect_raises(IndexError) { SafeIndexableMutable.new(5)[5] = 0 }
      expect_raises(IndexError) { SafeIndexableMutable.new(5)[-6] = 0 }
    end
  end

  describe "#update" do
    it "updates the value at the given index with the block" do
      coll = SafeIndexableMutable.new(5)
      coll.update(2) { |x| x + 7 }.should eq(9)
      coll[2].should eq(9)

      coll = SafeIndexableMutableFoo.new(5)
      foo = Foo.new
      coll.update(2) { foo }.should be(foo)
      coll[2].should be(foo)
    end

    it "wraps negative indices" do
      coll = SafeIndexableMutable.new(5)
      coll.update(-2) { |x| x + 7 }.should eq(10)
      coll[3].should eq(10)

      coll.update(-5) { |x| x + 14 }.should eq(14)
      coll[0].should eq(14)
    end

    it "raises on out-of-bound indices" do
      expect_raises(IndexError) { SafeIndexableMutable.new(5).update(5, &.itself) }
      expect_raises(IndexError) { SafeIndexableMutable.new(5).update(-6, &.itself) }
    end
  end

  describe "#swap" do
    it "exchanges the values at two indices" do
      coll = SafeIndexableMutable.new(12, offset: 50)
      coll.swap(2, 7).should be(coll)
      coll[2].should eq(57)
      coll[7].should eq(52)

      coll = SafeIndexableMutableFoo.new(12)
      foo2 = coll[2]
      foo7 = coll[7]
      coll.swap(2, 7).should be(coll)
      coll[2].should be(foo7)
      coll[7].should be(foo2)
    end

    it "wraps negative indices" do
      coll = SafeIndexableMutable.new(12, offset: 50)
      coll.swap(-3, -7).should be(coll)
      coll[9].should eq(55)
      coll[5].should eq(59)
    end

    it "raises on out-of-bound indices" do
      expect_raises(IndexError) { SafeIndexableMutable.new(5).swap(5, 5) }
      expect_raises(IndexError) { SafeIndexableMutable.new(5).swap(-6, -6) }
    end
  end

  describe "#reverse!" do
    it "reverses the order of all elements in place" do
      coll = SafeIndexableMutable.new(5)
      coll.reverse!.should be(coll)
      coll.to_a.should eq([4, 3, 2, 1, 0])

      coll = SafeIndexableMutable.new(8)
      coll.reverse!.should be(coll)
      coll.to_a.should eq([7, 6, 5, 4, 3, 2, 1, 0])

      coll = SafeIndexableMutableFoo.new(5)
      foos = coll.to_a
      coll.reverse!.should be(coll)
      coll.to_a.should eq([foos[4], foos[3], foos[2], foos[1], foos[0]])

      coll = SafeIndexableMutableFoo.new(8)
      foos = coll.to_a
      coll.reverse!.should be(coll)
      coll.to_a.should eq([foos[7], foos[6], foos[5], foos[4], foos[3], foos[2], foos[1], foos[0]])
    end
  end

  describe "#fill" do
    context "without block" do
      it "sets all elements to the same value" do
        coll = SafeIndexableMutable.new(5)
        coll.fill(4)
        coll.to_a.should eq([4, 4, 4, 4, 4])

        coll = SafeIndexableMutableFoo.new(5)
        foo = Foo.new
        coll.fill(foo)
        coll.to_a.should eq([foo, foo, foo, foo, foo])
      end
    end

    context "with block" do
      it "yields index to the block and sets all elements" do
        coll = SafeIndexableMutable.new(5)
        coll.fill { |i| i * i }
        coll.to_a.should eq([0, 1, 4, 9, 16])

        coll = SafeIndexableMutableFoo.new(5)
        foo = Foo.new
        coll.fill { foo }
        coll.to_a.should eq([foo, foo, foo, foo, foo])
      end
    end

    context "with block + offset" do
      it "yields index plus offset to the block and sets all elements" do
        coll = SafeIndexableMutable.new(5)
        coll.fill(offset: 7) { |i| i * i }
        coll.to_a.should eq([49, 64, 81, 100, 121])

        coll = SafeIndexableMutableFoo.new(5)
        foos = coll.to_a
        coll.fill(offset: -2) { |i| foos[i] }
        coll.to_a.should eq([foos[-2], foos[-1], foos[0], foos[1], foos[2]])
      end
    end
  end

  describe "#map!" do
    it "replaces each element with the block value" do
      coll = SafeIndexableMutable.new(5, offset: 2)
      coll.map! { |i| 10 - i }
      coll.to_a.should eq([8, 7, 6, 5, 4])

      coll = SafeIndexableMutableFoo.new(5)
      foos = coll.to_a
      coll.map! &.itself
      coll.to_a.should eq(foos)
    end
  end

  describe "#map_with_index!" do
    context "without offset" do
      it "yields each element and index to the block" do
        coll = SafeIndexableMutable.new(5)
        coll[2] = 4
        coll[4] = 7
        coll.map_with_index! { |v, i| v * 100 + i }
        coll.to_a.should eq([0, 101, 402, 303, 704])
      end
    end

    context "with offset" do
      it "yields each element and index plus offset to the block" do
        coll = SafeIndexableMutable.new(5)
        coll[2] = 4
        coll[4] = 7
        coll.map_with_index!(offset: 4) { |v, i| v * 100 + i }
        coll.to_a.should eq([4, 105, 406, 307, 708])
      end
    end
  end

  describe "#shuffle!" do
    it "randomizes the order of all elements" do
      coll = SafeIndexableMutable.new(5)
      coll.shuffle!(Random.new(42)).should be(coll)
      coll.to_a.should eq([2, 1, 3, 4, 0])

      coll = SafeIndexableMutableFoo.new(5)
      foos = coll.to_a
      coll.shuffle!(Random.new(42)).should be(coll)
      coll.to_a.should eq([foos[2], foos[1], foos[3], foos[4], foos[0]])
    end
  end

  describe "#rotate!" do
    it "left-shifts all elements" do
      coll = SafeIndexableMutable.new(5)
      coll.rotate!(2).should be(coll)
      coll.to_a.should eq([2, 3, 4, 0, 1])

      coll = SafeIndexableMutableFoo.new(5)
      foos = coll.to_a
      coll.rotate!(3).should be(coll)
      coll.to_a.should eq([foos[3], foos[4], foos[0], foos[1], foos[2]])

      SafeIndexableMutable.new(6).rotate!(2).to_a.should eq([2, 3, 4, 5, 0, 1])
      SafeIndexableMutable.new(6).rotate!(0).to_a.should eq([0, 1, 2, 3, 4, 5])
      SafeIndexableMutable.new(6).rotate!(12).to_a.should eq([0, 1, 2, 3, 4, 5])
      SafeIndexableMutable.new(6).rotate!(-1).to_a.should eq([5, 0, 1, 2, 3, 4])
      SafeIndexableMutable.new(10).rotate!(6).to_a.should eq([6, 7, 8, 9, 0, 1, 2, 3, 4, 5])
      SafeIndexableMutable.new(10).rotate!(12345678).to_a.should eq([8, 9, 0, 1, 2, 3, 4, 5, 6, 7])
      SafeIndexableMutable.new(10).rotate!(-1234567).to_a.should eq([3, 4, 5, 6, 7, 8, 9, 0, 1, 2])
    end
  end
end
