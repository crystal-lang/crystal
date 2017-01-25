require "spec"

private class DequeTester
  # Execute the same actions on an Array and a Deque and compare them at each step.

  @deque : Deque(Int32)
  @array : Array(Int32)
  @i : Int32
  @c : Array(Int32) | Deque(Int32) | Nil

  def step
    @c = @deque
    yield
    @c = @array
    yield
    @deque.to_a.should eq(@array)
    @i += 1
  end

  def initialize
    @deque = Deque(Int32).new
    @array = Array(Int32).new
    @i = 1
  end

  getter i

  def c
    @c.not_nil!
  end

  def test
    with self yield
  end
end

private alias RecursiveDeque = Deque(RecursiveDeque)

describe "Deque" do
  describe "implementation" do
    it "works the same as array" do
      DequeTester.new.test do
        step { c.unshift i }
        step { c.pop }
        step { c.push i }
        step { c.shift }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.pop }
        step { c.shift }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.push i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.unshift i }
        step { c.insert(1, i) }
        step { c.insert(0, i) }
        step { c.insert(17, i) }
        step { c.insert(14, i) }
        step { c.insert(10, i) }
        step { c.insert(10, i) }
      end
    end

    it "works the same as array when inserting at 1/8 size and deleting at 3/4 size" do
      DequeTester.new.test do
        1000.times do
          step { c.insert(c.size / 8, i) }
        end
        1000.times do
          step { c.delete_at(c.size * 3 / 4) }
        end
      end
    end

    it "works the same as array when inserting at 3/4 size and deleting at 1/8 size" do
      DequeTester.new.test do
        1000.times do
          step { c.insert(c.size * 3 / 4, i) }
        end
        1000.times do
          step { c.delete_at(c.size / 8) }
        end
      end
    end
  end

  describe "new" do
    it "creates with default value" do
      deq = Deque.new(5, 3)
      deq.should eq(Deque{3, 3, 3, 3, 3})
    end

    it "creates with default value in block" do
      deq = Deque.new(5) { |i| i * 2 }
      deq.should eq(Deque{0, 2, 4, 6, 8})
    end

    it "creates from an array" do
      deq = Deque(Int32).new([1, 2, 3, 4, 5])
      deq.should eq(Deque{1, 2, 3, 4, 5})
    end

    it "raises on negative count" do
      expect_raises(ArgumentError, "Negative deque size") do
        Deque.new(-1, 3)
      end
    end

    it "raises on negative capacity" do
      expect_raises(ArgumentError, "Negative deque capacity") do
        Deque(Int32).new(-1)
      end
    end
  end

  describe "==" do
    it "compares empty" do
      Deque(Int32).new.should eq(Deque(Int32).new)
      Deque{1}.should_not eq(Deque(Int32).new)
      Deque(Int32).new.should_not eq(Deque{1})
    end

    it "compares elements" do
      Deque{1, 2, 3}.should eq(Deque{1, 2, 3})
      Deque{1, 2, 3}.should_not eq(Deque{3, 2, 1})
    end

    it "compares other" do
      a = Deque{1, 2, 3}
      b = Deque{1, 2, 3}
      c = Deque{1, 2, 3, 4}
      d = Deque{1, 2, 4}
      (a == b).should be_true
      (b == c).should be_false
      (a == d).should be_false
    end
  end

  describe "+" do
    it "does +" do
      a = Deque{1, 2, 3}
      b = Deque{4, 5}
      c = a + b
      c.size.should eq(5)
      0.upto(4) { |i| c[i].should eq(i + 1) }
    end

    it "does + with different types" do
      a = Deque{1, 2, 3}
      a += Deque{"hello"}
      a.should eq(Deque{1, 2, 3, "hello"})
    end
  end

  describe "[]" do
    it "gets on positive index" do
      Deque{1, 2, 3}[1].should eq(2)
    end

    it "gets on negative index" do
      Deque{1, 2, 3}[-1].should eq(3)
    end

    it "gets nilable" do
      Deque{1, 2, 3}[2]?.should eq(3)
      Deque{1, 2, 3}[3]?.should be_nil
    end

    it "same access by at" do
      Deque{1, 2, 3}[1].should eq(Deque{1, 2, 3}.at(1))
    end
  end

  describe "[]=" do
    it "sets on positive index" do
      a = Deque{1, 2, 3}
      a[1] = 4
      a[1].should eq(4)
    end

    it "sets on negative index" do
      a = Deque{1, 2, 3}
      a[-1] = 4
      a[2].should eq(4)
    end
  end

  it "does clear" do
    a = Deque{1, 2, 3}
    a.clear
    a.should eq(Deque(Int32).new)
  end

  it "does clone" do
    x = {1 => 2}
    a = Deque{x}
    b = a.clone
    b.should eq(a)
    a.should_not be(b)
    a[0].should_not be(b[0])
  end

  describe "concat" do
    it "concats deque" do
      a = Deque{1, 2, 3}
      a.concat(Deque{4, 5, 6})
      a.should eq(Deque{1, 2, 3, 4, 5, 6})
    end

    it "concats large deques" do
      a = Deque{1, 2, 3}
      a.concat((4..1000).to_a)
      a.should eq(Deque.new((1..1000).to_a))
    end

    it "concats enumerable" do
      a = Deque{1, 2, 3}
      a.concat((4..1000))
      a.should eq(Deque.new((1..1000).to_a))
    end
  end

  describe "delete" do
    it "deletes many" do
      a = Deque{1, 2, 3, 1, 2, 3}
      a.delete(2).should be_true
      a.should eq(Deque{1, 3, 1, 3})
    end

    it "delete not found" do
      a = Deque{1, 2}
      a.delete(4).should be_false
      a.should eq(Deque{1, 2})
    end
  end

  describe "delete_at" do
    it "deletes positive index" do
      a = Deque{1, 2, 3, 4, 5}
      a.delete_at(3).should eq(4)
      a.should eq(Deque{1, 2, 3, 5})
    end

    it "deletes negative index" do
      a = Deque{1, 2, 3, 4, 5}
      a.delete_at(-4).should eq(2)
      a.should eq(Deque{1, 3, 4, 5})
    end

    it "deletes out of bounds" do
      a = Deque{1, 2, 3, 4}
      expect_raises IndexError do
        a.delete_at(4)
      end
    end
  end

  it "does dup" do
    x = {1 => 2}
    a = Deque{x}
    b = a.dup
    b.should eq(Deque{x})
    a.should_not be(b)
    a[0].should be(b[0])
    b << {3 => 4}
    a.should eq(Deque{x})
  end

  it "does each" do
    a = Deque{1, 1, 1}
    b = 0
    a.each { |i| b += i }.should be_nil
    b.should eq(3)
  end

  it "does each_index" do
    a = Deque{1, 1, 1}
    b = 0
    a.each_index { |i| b += i }.should be_nil
    b.should eq(3)
  end

  describe "empty" do
    it "is empty" do
      (Deque(Int32).new.empty?).should be_true
    end

    it "is not empty" do
      Deque{1}.empty?.should be_false
    end
  end

  it "does equals? with custom block" do
    a = Deque{1, 3, 2}
    b = Deque{3, 9, 4}
    c = Deque{5, 7, 3}
    d = Deque{1, 3, 2, 4}
    f = ->(x : Int32, y : Int32) { (x % 2) == (y % 2) }
    a.equals?(b, &f).should be_true
    a.equals?(c, &f).should be_false
    a.equals?(d, &f).should be_false
  end

  describe "first" do
    it "gets first when non empty" do
      a = Deque{1, 2, 3}
      a.first.should eq(1)
    end

    it "raises when empty" do
      expect_raises IndexError do
        Deque(Int32).new.first
      end
    end
  end

  describe "first?" do
    it "gets first? when non empty" do
      a = Deque{1, 2, 3}
      a.first?.should eq(1)
    end

    it "gives nil when empty" do
      Deque(Int32).new.first?.should be_nil
    end
  end

  it "does hash" do
    a = Deque{1, 2, Deque{3}}
    b = Deque{1, 2, Deque{3}}
    a.hash.should eq(b.hash)
  end

  describe "insert" do
    it "inserts with positive index" do
      a = Deque{1, 3, 4}
      expected = Deque{1, 2, 3, 4}
      a.insert(1, 2).should eq(expected)
      a.should eq(expected)
    end

    it "inserts with negative index" do
      a = Deque{1, 2, 3}
      expected = Deque{1, 2, 3, 4}
      a.insert(-1, 4).should eq(expected)
      a.should eq(expected)
    end

    it "inserts with negative index (2)" do
      a = Deque{1, 2, 3}
      expected = Deque{4, 1, 2, 3}
      a.insert(-4, 4).should eq(expected)
      a.should eq(expected)
    end

    it "inserts out of range" do
      a = Deque{1, 3, 4}

      expect_raises IndexError do
        a.insert(4, 1)
      end
    end
  end

  describe "inspect" do
    it { Deque{1, 2, 3}.inspect.should eq("Deque{1, 2, 3}") }
  end

  describe "last" do
    it "gets last when non empty" do
      a = Deque{1, 2, 3}
      a.last.should eq(3)
    end

    it "raises when empty" do
      expect_raises IndexError do
        Deque(Int32).new.last
      end
    end
  end

  describe "size" do
    it "has size 0" do
      Deque(Int32).new.size.should eq(0)
    end

    it "has size 2" do
      Deque{1, 2}.size.should eq(2)
    end
  end

  describe "pop" do
    it "pops when non empty" do
      a = Deque{1, 2, 3}
      a.pop.should eq(3)
      a.should eq(Deque{1, 2})
    end

    it "raises when empty" do
      expect_raises IndexError do
        Deque(Int32).new.pop
      end
    end

    it "pops many elements" do
      a = Deque{1, 2, 3, 4, 5}
      a.pop(3)
      a.should eq(Deque{1, 2})
    end

    it "pops more elements than what is available" do
      a = Deque{1, 2, 3, 4, 5}
      a.pop(10)
      a.should eq(Deque(Int32).new)
    end

    it "pops negative count raises" do
      a = Deque{1, 2}
      expect_raises ArgumentError do
        a.pop(-1)
      end
    end
  end

  describe "push" do
    it "adds one element to the deque" do
      a = Deque{"a", "b"}
      a.push("c")
      a.should eq Deque{"a", "b", "c"}
    end

    it "returns the deque" do
      a = Deque{"a", "b"}
      a.push("c").should eq Deque{"a", "b", "c"}
    end

    it "has the << alias" do
      a = Deque{"a", "b"}
      a << "c"
      a.should eq Deque{"a", "b", "c"}
    end
  end

  describe "rotate!" do
    it "rotates" do
      a = Deque{1, 2, 3, 4, 5}
      a.rotate!
      a.should eq(Deque{2, 3, 4, 5, 1})
      a.rotate!(-2)
      a.should eq(Deque{5, 1, 2, 3, 4})
      a.rotate!(10)
      a.should eq(Deque{5, 1, 2, 3, 4})
    end

    it "rotates with size=capacity" do
      a = Deque{1, 2, 3, 4}
      a.rotate!
      a.should eq(Deque{2, 3, 4, 1})
      a.rotate!(-2)
      a.should eq(Deque{4, 1, 2, 3})
      a.rotate!(8)
      a.should eq(Deque{4, 1, 2, 3})
    end
  end

  describe "shift" do
    it "shifts when non empty" do
      a = Deque{1, 2, 3}
      a.shift.should eq(1)
      a.should eq(Deque{2, 3})
    end

    it "raises when empty" do
      expect_raises IndexError do
        Deque(Int32).new.shift
      end
    end

    it "shifts many elements" do
      a = Deque{1, 2, 3, 4, 5}
      a.shift(3)
      a.should eq(Deque{4, 5})
    end

    it "shifts more than what is available" do
      a = Deque{1, 2, 3, 4, 5}
      a.shift(10)
      a.should eq(Deque(Int32).new)
    end

    it "shifts negative count raises" do
      a = Deque{1, 2}
      expect_raises ArgumentError do
        a.shift(-1)
      end
    end
  end

  describe "swap" do
    it "swaps" do
      a = Deque{1, 2, 3}
      a.swap(0, 2)
      a.should eq(Deque{3, 2, 1})
    end

    it "swaps with negative indices" do
      a = Deque{1, 2, 3}
      a.swap(-3, -1)
      a.should eq(Deque{3, 2, 1})
    end

    it "swaps but raises out of bounds on left" do
      a = Deque{1, 2, 3}
      expect_raises IndexError do
        a.swap(3, 0)
      end
    end

    it "swaps but raises out of bounds on right" do
      a = Deque{1, 2, 3}
      expect_raises IndexError do
        a.swap(0, 3)
      end
    end
  end

  describe "to_s" do
    it "does to_s" do
      it { Deque{1, 2, 3}.to_s.should eq("Deque{1, 2, 3}") }
    end

    it "does with recursive" do
      deq = Deque(RecursiveDeque).new
      deq << deq
      deq.to_s.should eq("Deque{Deque{...}}")
    end
  end

  it "does unshift" do
    a = Deque{2, 3}
    expected = Deque{1, 2, 3}
    a.unshift(1).should eq(expected)
    a.should eq(expected)
  end

  describe "each iterator" do
    it "does next" do
      a = Deque{1, 2, 3}
      iter = a.each
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should eq(3)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "cycles" do
      Deque{1, 2, 3}.cycle.first(8).join.should eq("12312312")
    end

    it "works while modifying deque" do
      a = Deque{1, 2, 3}
      count = 0
      it = a.each
      it.each do
        count += 1
        a.clear
      end
      count.should eq(1)
    end
  end

  describe "each_index iterator" do
    it "does next" do
      a = Deque{1, 2, 3}
      iter = a.each_index
      iter.next.should eq(0)
      iter.next.should eq(1)
      iter.next.should eq(2)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(0)
    end

    it "works while modifying deque" do
      a = Deque{1, 2, 3}
      count = 0
      it = a.each_index
      a.each_index.each do
        count += 1
        a.clear
      end
      count.should eq(1)
    end
  end

  describe "reverse each iterator" do
    it "does next" do
      a = Deque{1, 2, 3}
      iter = a.reverse_each
      iter.next.should eq(3)
      iter.next.should eq(2)
      iter.next.should eq(1)
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(3)
    end
  end

  describe "cycle" do
    it "cycles" do
      a = [] of Int32
      Deque{1, 2, 3}.cycle do |x|
        a << x
        break if a.size == 9
      end
      a.should eq([1, 2, 3, 1, 2, 3, 1, 2, 3])
    end

    it "cycles N times" do
      a = [] of Int32
      Deque{1, 2, 3}.cycle(2) do |x|
        a << x
      end
      a.should eq([1, 2, 3, 1, 2, 3])
    end

    it "cycles with iterator" do
      Deque{1, 2, 3}.cycle.first(5).to_a.should eq([1, 2, 3, 1, 2])
    end

    it "cycles with N and iterator" do
      Deque{1, 2, 3}.cycle(2).to_a.should eq([1, 2, 3, 1, 2, 3])
    end
  end
end
