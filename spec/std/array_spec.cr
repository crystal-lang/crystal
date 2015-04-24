require "spec"

alias RecursiveArray = Array(RecursiveArray)

describe "Array" do
  describe "==" do
    it "compares empty" do
      expect(([] of Int32)).to eq([] of Int32)
      expect([1]).to_not eq([] of Int32)
      expect(([] of Int32)).to_not eq([1])
    end

    it "compares elements" do
      expect([1, 2, 3]).to eq([1, 2, 3])
      expect([1, 2, 3]).to_not eq([3, 2, 1])
    end

    it "compares other" do
      a = [1, 2, 3]
      b = [1, 2, 3]
      c = [1, 2, 3, 4]
      d = [1, 2, 4]
      expect((a == b)).to be_true
      expect((b == c)).to be_false
      expect((a == d)).to be_false
    end
  end

  it "does &" do
    expect(([1, 2, 3] & [] of Int32)).to eq([] of Int32)
    expect(([] of Int32 & [1, 2, 3])).to eq([] of Int32)
    expect(([1, 2, 3] & [3, 2, 4])).to eq([2, 3])
    expect(([1, 2, 3, 1, 2, 3] & [3, 2, 4, 3, 2, 4])).to eq([2, 3])
    expect(([1, 2, 3, 1, 2, 3, nil, nil] & [3, 2, 4, 3, 2, 4, nil])).to eq([2, 3, nil])
  end

  it "does |" do
    expect(([1, 2, 3] | [5, 3, 2, 4])).to eq([1, 2, 3, 5, 4])
    expect(([1, 1, 2, 3, 3] | [4, 5, 5, 6])).to eq([1, 2, 3, 4, 5, 6])
  end

  it "does +" do
    a = [1, 2, 3]
    b = [4, 5]
    c = a + b
    expect(c.length).to eq(5)
    0.upto(4) { |i| expect(c[i]).to eq(i + 1) }
  end

  it "does -" do
    expect(([1, 2, 3, 4, 5] - [4, 2])).to eq([1, 3, 5])
  end

  describe "[]" do
    it "gets on positive index" do
      expect([1, 2, 3][1]).to eq(2)
    end

    it "gets on negative index" do
      expect([1, 2, 3][-1]).to eq(3)
    end

    it "gets on inclusive range" do
      expect([1, 2, 3, 4, 5, 6][1 .. 4]).to eq([2, 3, 4, 5])
    end

    it "gets on inclusive range with negative indices" do
      expect([1, 2, 3, 4, 5, 6][-5 .. -2]).to eq([2, 3, 4, 5])
    end

    it "gets on exclusive range" do
      expect([1, 2, 3, 4, 5, 6][1 ... 4]).to eq([2, 3, 4])
    end

    it "gets on exclusive range with negative indices" do
      expect([1, 2, 3, 4, 5, 6][-5 ... -2]).to eq([2, 3, 4])
    end

    it "gets on empty range" do
      expect([1, 2, 3][3 .. 1]).to eq([] of Int32)
    end

    it "gets with start and count" do
      expect([1, 2, 3, 4, 5, 6][1, 3]).to eq([2, 3, 4])
    end

    it "gets with start and count exceeding length" do
      expect([1, 2, 3][1, 3]).to eq([2, 3])
    end

    it "gets with negative start " do
      expect([1, 2, 3, 4, 5, 6][-4, 2]).to eq([3, 4])
    end

    it "raises on index out of bounds" do
      expect_raises IndexOutOfBounds do
        [1, 2, 3][-4, 2]
      end
    end

    it "raises on negative count" do
      expect_raises ArgumentError, /negative count: -1/ do
        [1, 2, 3][1, -1]
      end
    end

    it "gets 0, 0 on empty array" do
      a = [] of Int32
      expect(a[0, 0]).to eq(a)
    end

    it "gets 0 ... 0 on empty array" do
      a = [] of Int32
      expect(a[0 .. 0]).to eq(a)
    end

    it "gets nilable" do
      expect([1, 2, 3][2]?).to eq(3)
      expect([1, 2, 3][3]?).to be_nil
    end

    it "same access by at" do
      expect([1, 2, 3][1]).to eq([1,2,3].at(1))
    end

    it "doesn't exceed limits" do
      expect([1][0..3]).to eq([1])
    end

    it "returns empty if at end" do
      expect([1][1, 0]).to eq([] of Int32)
      expect([1][1, 10]).to eq([] of Int32)
    end
  end

  describe "[]=" do
    it "sets on positive index" do
      a = [1, 2, 3]
      a[1] = 4
      expect(a[1]).to eq(4)
    end

    it "sets on negative index" do
      a = [1, 2, 3]
      a[-1] = 4
      expect(a[2]).to eq(4)
    end
  end

  it "does clear" do
    a = [1, 2, 3]
    a.clear
    expect(a).to eq([] of Int32)
  end

  it "does clone" do
    x = {1 => 2}
    a = [x]
    b = a.clone
    expect(b).to eq(a)
    expect(a.object_id).to_not eq(b.object_id)
    expect(a[0].object_id).to_not eq(b[0].object_id)
  end

  it "does compact" do
    a = [1, nil, 2, nil, 3]
    expect(b = a.compact).to eq([1, 2, 3])
    expect(a).to eq([1, nil, 2, nil, 3])
  end

  describe "compact!" do
    it "returns true if removed" do
      a = [1, nil, 2, nil, 3]
      expect(b = a.compact!).to be_true
      expect(a).to eq([1, 2, 3])
    end

    it "returns false if not removed" do
      a = [1]
      expect(b = a.compact!).to be_false
      expect(a).to eq([1])
    end
  end

  describe "concat" do
    it "concats small arrays" do
      a = [1, 2, 3]
      a.concat([4, 5, 6])
      expect(a).to eq([1, 2, 3, 4, 5, 6])
    end

    it "concats large arrays" do
      a = [1, 2, 3]
      a.concat((4..1000).to_a)
      expect(a).to eq((1..1000).to_a)
    end

    it "concats enumerable" do
      a = [1, 2, 3]
      a.concat((4..1000))
      expect(a).to eq((1..1000).to_a)
    end
  end

  describe "delete" do
    it "deletes many" do
      a = [1, 2, 3, 1, 2, 3]
      expect(a.delete(2)).to be_true
      expect(a).to eq([1, 3, 1, 3])
    end

    it "delete not found" do
      a = [1, 2]
      expect(a.delete(4)).to be_false
      expect(a).to eq([1, 2])
    end
  end

  describe "delete_at" do
    it "deletes positive index" do
      a = [1, 2, 3, 4]
      expect(a.delete_at(1)).to eq(2)
      expect(a).to eq([1, 3, 4])
    end

    it "deletes negative index" do
      a = [1, 2, 3, 4]
      expect(a.delete_at(-3)).to eq(2)
      expect(a).to eq([1, 3, 4])
    end

    it "deletes out of bounds" do
      a = [1, 2, 3, 4]
      expect_raises IndexOutOfBounds do
        a.delete_at(4)
      end
    end
  end

  describe "delete_if" do
    it "deletes many" do
      a = [1, 2, 3, 1, 2, 3]
      a.delete_if { |i| i > 2 }
      expect(a).to eq([1, 2, 1, 2])
    end
  end

  it "does dup" do
    x = {1 => 2}
    a = [x]
    b = a.dup
    expect(b).to eq([x])
    expect(a.object_id).to_not eq(b.object_id)
    expect(a[0].object_id).to eq(b[0].object_id)
    b << {3 => 4}
    expect(a).to eq([x])
  end

  it "does each_index" do
    a = [1, 1, 1]
    b = 0
    a.each_index { |i| b += i }
    expect(b).to eq(3)
  end

  describe "empty" do
    it "is empty" do
      expect(([] of Int32).empty?).to be_true
      expect([1].empty?).to be_false
    end

    it "is not empty" do
      expect([1].empty?).to be_false
    end
  end

  it "does equals? with custom block" do
    a = [1, 3, 2]
    b = [3, 9, 4]
    c = [5, 7, 3]
    d = [1, 3, 2, 4]
    f = ->(x : Int32, y : Int32) { (x % 2) == (y % 2) }
    expect(a.equals?(b, &f)).to be_true
    expect(a.equals?(c, &f)).to be_false
    expect(a.equals?(d, &f)).to be_false
  end

  describe "fill" do
    it "replaces all values" do
      a = ['a', 'b', 'c']
      expected = ['x', 'x', 'x']
      expect(a.fill('x')).to eq(expected)
    end

    it "replaces only values between index and size" do
      a = ['a', 'b', 'c']
      expected = ['x', 'x', 'c']
      expect(a.fill('x', 0, 2)).to eq(expected)
    end

    it "replaces only values between index and size (2)" do
      a = ['a', 'b', 'c']
      expected = ['a', 'x', 'x']
      expect(a.fill('x', 1, 2)).to eq(expected)
    end

    it "replaces all values from index onwards" do
      a = ['a', 'b', 'c']
      expected = ['a', 'x', 'x']
      expect(a.fill('x', -2)).to eq(expected)
    end

    it "replaces only values between negative index and size" do
      a = ['a', 'b', 'c']
      expected = ['a', 'b', 'x']
      expect(a.fill('x', -1, 1)).to eq(expected)
    end

    it "replaces only values in range" do
      a = ['a', 'b', 'c']
      expected = ['x', 'x', 'c']
      expect(a.fill('x', -3..1)).to eq(expected)
    end

    it "works with a block" do
      a = [3, 6, 9]
      expect(a.clone.fill { 0 }).to eq([0, 0, 0])
      expect(a.clone.fill { |i| i }).to eq([0, 1, 2])
      expect(a.clone.fill(1) { |i| (i ** i).to_i }).to eq([3, 1, 4])
      expect(a.clone.fill(1, 1) { |i| (i ** i).to_i }).to eq([3, 1, 9])
      expect(a.clone.fill(1..1) { |i| (i ** i).to_i }).to eq([3, 1, 9])
    end
  end

  describe "first" do
    it "gets first when non empty" do
      a = [1, 2, 3]
      expect(a.first).to eq(1)
    end

    it "raises when empty" do
      expect_raises IndexOutOfBounds do
        ([] of Int32).first
      end
    end
  end

  describe "first?" do
    it "gets first? when non empty" do
      a = [1, 2, 3]
      expect(a.first?).to eq(1)
    end

    it "gives nil when empty" do
      expect(([] of Int32).first?).to be_nil
    end
  end

  describe "flat_map" do
    it "does example 1" do
      expect([1, 2, 3, 4].flat_map { |e| [e, -e] }).to eq([1, -1, 2, -2, 3, -3, 4, -4])
    end

    it "does example 2" do
      expect([[1, 2], [3, 4]].flat_map { |e| e + [100] }).to eq([1, 2, 100, 3, 4, 100])
    end
  end

  it "does hash" do
    a = [1, 2, [3]]
    b = [1, 2, [3]]
    expect(a.hash).to eq(b.hash)
  end

  describe "index" do
    it "performs without a block" do
      a = [1, 2, 3]
      expect(a.index(3)).to eq(2)
      expect(a.index(4)).to be_nil
    end

    it "performs with a block" do
      a = [1, 2, 3]
      expect(a.index { |i| i > 1 }).to eq(1)
      expect(a.index { |i| i > 3 }).to be_nil
    end

    it "raises if out of bounds" do
      expect_raises IndexOutOfBounds do
        [1, 2, 3][4]
      end
    end
  end

  describe "insert" do
    it "inserts with positive index" do
      a = [1, 3, 4]
      expected = [1, 2, 3, 4]
      expect(a.insert(1, 2)).to eq(expected)
      expect(a).to eq(expected)
    end

    it "inserts with negative index" do
      a = [1, 2, 3]
      expected = [1, 2, 3, 4]
      expect(a.insert(-1, 4)).to eq(expected)
      expect(a).to eq(expected)
    end

    it "inserts with negative index (2)" do
      a = [1, 2, 3]
      expected = [4, 1, 2, 3]
      expect(a.insert(-4, 4)).to eq(expected)
      expect(a).to eq(expected)
    end

    it "inserts out of range" do
      a = [1, 3, 4]

      expect_raises IndexOutOfBounds do
        a.insert(4, 1)
      end
    end
  end

  describe "inspect" do
    assert { expect([1, 2, 3].inspect).to eq("[1, 2, 3]") }
  end

  describe "last" do
    it "gets last when non empty" do
      a = [1, 2, 3]
      expect(a.last).to eq(3)
    end

    it "raises when empty" do
      expect_raises IndexOutOfBounds do
        ([] of Int32).last
      end
    end
  end

  describe "length" do
    it "has length 0" do
      expect(([] of Int32).length).to eq(0)
    end

    it "has length 2" do
      expect([1, 2].length).to eq(2)
    end
  end

  it "does map" do
    a = [1, 2, 3]
    expect(a.map { |x| x * 2 }).to eq([2, 4, 6])
    expect(a).to eq([1, 2, 3])
  end

  it "does map!" do
    a = [1, 2, 3]
    a.map! { |x| x * 2 }
    expect(a).to eq([2, 4, 6])
  end

  describe "pop" do
    it "pops when non empty" do
      a = [1, 2, 3]
      expect(a.pop).to eq(3)
      expect(a).to eq([1, 2])
    end

    it "raises when empty" do
      expect_raises IndexOutOfBounds do
        ([] of Int32).pop
      end
    end

    it "pops many elements" do
      a = [1, 2, 3, 4, 5]
      b = a.pop(3)
      expect(b).to eq([3, 4, 5])
      expect(a).to eq([1, 2])
    end

    it "pops more elements that what is available" do
      a = [1, 2, 3, 4, 5]
      b = a.pop(10)
      expect(b).to eq([1, 2, 3, 4, 5])
      expect(a).to eq([] of Int32)
    end

    it "pops negative count raises" do
      a = [1, 2]
      expect_raises ArgumentError do
        a.pop(-1)
      end
    end
  end

  it "does product" do
    r = [] of Int32
    [1,2,3].product([5,6]) { |a, b| r << a; r << b }
    expect(r).to eq([1,5,1,6,2,5,2,6,3,5,3,6])
  end

  it "does replace" do
    a = [1, 2, 3]
    b = [1]
    b.replace a
    expect(b).to eq(a)
  end

  it "does reverse with an odd number of elements" do
    a = [1, 2, 3]
    expect(a.reverse).to eq([3, 2, 1])
    expect(a).to eq([1, 2, 3])
  end

  it "does reverse with an even number of elements" do
    a = [1, 2, 3, 4]
    expect(a.reverse).to eq([4, 3, 2, 1])
    expect(a).to eq([1, 2, 3, 4])
  end

  it "does reverse! with an odd number of elements" do
    a = [1, 2, 3, 4, 5]
    a.reverse!
    expect(a).to eq([5, 4, 3, 2, 1])
  end

  it "does reverse! with an even number of elements" do
    a = [1, 2, 3, 4, 5, 6]
    a.reverse!
    expect(a).to eq([6, 5, 4, 3, 2, 1])
  end

  describe "rindex" do
    it "performs without a block" do
      a = [1, 2, 3, 4, 5, 3, 6]
      expect(a.rindex(3)).to eq(5)
      expect(a.rindex(7)).to be_nil
    end

    it "performs with a block" do
      a = [1, 2, 3, 4, 5, 3, 6]
      expect(a.rindex { |i| i > 1 }).to eq(6)
      expect(a.rindex { |i| i > 6 }).to be_nil
    end
  end

  describe "sample" do
    it "sample" do
      expect([1].sample).to eq(1)

      x = [1, 2, 3].sample
      expect([1, 2, 3].includes?(x)).to be_true
    end

    it "gets sample of negative count elements raises" do
      expect_raises ArgumentError do
        [1].sample(-1)
      end
    end

    it "gets sample of 0 elements" do
      expect([1].sample(0)).to eq([] of Int32)
    end

    it "gets sample of 1 elements" do
      expect([1].sample(1)).to eq([1])

      x = [1, 2, 3].sample(1)
      expect(x.length).to eq(1)
      x = x.first
      expect([1, 2, 3].includes?(x)).to be_true
    end

    it "gets sample of k elements out of n" do
      a = [1, 2, 3, 4, 5]
      b = a.sample(3)
      set = Set.new(b)
      expect(set.length).to eq(3)

      set.each do |e|
        expect(a.includes?(e)).to be_true
      end
    end

    it "gets sample of k elements out of n, where k > n" do
      a = [1, 2, 3, 4, 5]
      b = a.sample(10)
      expect(b.length).to eq(5)
      set = Set.new(b)
      expect(set.length).to eq(5)

      set.each do |e|
        expect(a.includes?(e)).to be_true
      end
    end
  end

  describe "shift" do
    it "shifts when non empty" do
      a = [1, 2, 3]
      expect(a.shift).to eq(1)
      expect(a).to eq([2, 3])
    end

    it "raises when empty" do
      expect_raises IndexOutOfBounds do
        ([] of Int32).shift
      end
    end

    it "shifts many elements" do
      a = [1, 2, 3, 4, 5]
      b = a.shift(3)
      expect(b).to eq([1, 2, 3])
      expect(a).to eq([4, 5])
    end

    it "shifts more than what is available" do
      a = [1, 2, 3, 4, 5]
      b = a.shift(10)
      expect(b).to eq([1, 2, 3, 4, 5])
      expect(a).to eq([] of Int32)
    end

    it "shifts negative count raises" do
      a = [1, 2]
      expect_raises ArgumentError do
        a.shift(-1)
      end
    end
  end

  describe "shuffle" do
    it "shuffle!" do
      a = [1, 2, 3]
      a.shuffle!
      b = [1, 2, 3]
      3.times { expect(a.includes?(b.shift)).to be_true }
    end

    it "shuffle" do
      a = [1, 2, 3]
      b = a.shuffle
      expect(a.same?(b)).to be_false
      expect(a).to eq([1, 2, 3])

      3.times { expect(b.includes?(a.shift)).to be_true }
    end
  end

  describe "sort" do
    it "sort! without block" do
      a = [3, 4, 1, 2, 5, 6]
      a.sort!
      expect(a).to eq([1, 2, 3, 4, 5, 6])
    end

    it "sort without block" do
      a = [3, 4, 1, 2, 5, 6]
      b = a.sort
      expect(b).to eq([1, 2, 3, 4, 5, 6])
      expect(a).to_not eq(b)
    end

    it "sort! with a block" do
      a = ["foo", "a", "hello"]
      a.sort! { |x, y| x.length <=> y.length }
      expect(a).to eq(["a", "foo", "hello"])
    end

    it "sort with a block" do
      a = ["foo", "a", "hello"]
      b = a.sort { |x, y| x.length <=> y.length }
      expect(b).to eq(["a", "foo", "hello"])
      expect(a).to_not eq(b)
    end

    it "sorts by!" do
      a = ["foo", "a", "hello"]
      a.sort_by! &.length
      expect(a).to eq(["a", "foo", "hello"])
    end

    it "sorts by" do
      a = ["foo", "a", "hello"]
      b = a.sort_by &.length
      expect(b).to eq(["a", "foo", "hello"])
      expect(a).to_not eq(b)
    end
  end

  describe "swap" do
    it "swaps" do
      a = [1, 2, 3]
      a.swap(0, 2)
      expect(a).to eq([3, 2, 1])
    end

    it "swaps with negative indices" do
      a = [1, 2, 3]
      a.swap(-3, -1)
      expect(a).to eq([3, 2, 1])
    end

    it "swaps but raises out of bounds on left" do
      a = [1, 2, 3]
      expect_raises IndexOutOfBounds do
        a.swap(3, 0)
      end
    end

    it "swaps but raises out of bounds on right" do
      a = [1, 2, 3]
      expect_raises IndexOutOfBounds do
        a.swap(0, 3)
      end
    end
  end

  describe "to_s" do
    it "does to_s" do
      assert { expect([1, 2, 3].to_s).to eq("[1, 2, 3]") }
    end

    it "does with recursive" do
      ary = [] of RecursiveArray
      ary << ary
      expect(ary.to_s).to eq("[[...]]")
    end
  end

  describe "uniq" do
    it "uniqs without block" do
      a = [1, 2, 2, 3, 1, 4, 5, 3]
      b = a.uniq
      expect(b).to eq([1, 2, 3, 4, 5])
      expect(a.same?(b)).to be_false
    end

    it "uniqs with block" do
      a = [-1, 1, 0, 2, -2]
      b = a.uniq &.abs
      expect(b).to eq([-1, 0, 2])
      expect(a.same?(b)).to be_false
    end

    it "uniqs with true" do
      a = [1, 2, 3]
      b = a.uniq { true }
      expect(b).to eq([1])
      expect(a.same?(b)).to be_false
    end
  end

  describe "uniq!" do
    it "uniqs without block" do
      a = [1, 2, 2, 3, 1, 4, 5, 3]
      a.uniq!
      expect(a).to eq([1, 2, 3, 4, 5])
    end

    it "uniqs with block" do
      a = [-1, 1, 0, 2, -2]
      a.uniq! &.abs
      expect(a).to eq([-1, 0, 2])
    end

    it "uniqs with true" do
      a = [1, 2, 3]
      a.uniq! { true }
      expect(a).to eq([1])
    end
  end

  it "does unshift" do
    a = [2, 3]
    expected = [1, 2, 3]
    expect(a.unshift(1)).to eq(expected)
    expect(a).to eq(expected)
  end

  it "does update" do
    a = [1, 2, 3]
    a.update(1) { |x| x * 2 }
    expect(a).to eq([1, 4, 3])
  end

  it "does <=>" do
    a = [1, 2, 3]
    b = [4, 5, 6]
    c = [1, 2]

    expect((a <=> b)).to be < 1
    expect((a <=> c)).to be > 0
    expect((b <=> c)).to be > 0
    expect((b <=> a)).to be > 0
    expect((c <=> a)).to be < 0
    expect((c <=> b)).to be < 0
    expect((a <=> a)).to eq(0)

    expect(([8] <=> [1, 2, 3])).to be > 0
    expect(([8] <=> [8, 1, 2])).to be < 0

    expect([[1, 2, 3], [4, 5], [8], [1, 2, 3, 4]].sort).to eq([[1, 2, 3], [1, 2, 3, 4], [4, 5], [8]])
  end

  it "does each while modifying array" do
    a = [1, 2, 3]
    count = 0
    a.each do
      count += 1
      a.clear
    end
    expect(count).to eq(1)
  end

  it "does each index while modifying array" do
    a = [1, 2, 3]
    count = 0
    a.each_index do
      count += 1
      a.clear
    end
    expect(count).to eq(1)
  end

  describe "zip" do
    describe "when a block is provided" do
      it "yields pairs of self's elements and passed array" do
        a, b, r = [1, 2, 3], [4, 5, 6], ""
        a.zip(b) { |x, y| r += "#{x}:#{y}," }
        expect(r).to eq("1:4,2:5,3:6,")
      end
    end

    describe "when no block is provided" do
      describe "and the arrays have different typed elements" do
        it "returns an array of paired elements (tuples)" do
          a, b = [1, 2, 3], ["a", "b", "c"]
          r = a.zip(b)
          expect(r).to eq([{1, "a"}, {2, "b"}, {3, "c"}])
        end
      end
    end
  end

  it "does compact_map" do
    a = [1, 2, 3, 4, 5]
    b = a.compact_map { |e| e.divisible_by?(2) ? e : nil }
    expect(b.length).to eq(2)
    expect(b).to eq([2, 4])
  end

  it "does compact_map with false" do
    a = [1, 2, 3]
    b = a.compact_map do |e|
      case e
      when 1 then 1
      when 2 then nil
      else        false
      end
    end
    expect(b.length).to eq(2)
    expect(b).to eq([1, false])
  end

  it "builds from buffer" do
    ary = Array(Int32).build(4) do |buffer|
      buffer[0] = 1
      buffer[1] = 2
      2
    end
    expect(ary.length).to eq(2)
    expect(ary).to eq([1, 2])
  end

  it "does select!" do
    ary = [1, 2, 3, 4]
    ary2 = ary.select! { |x| x % 2 == 0 }
    expect(ary2).to be(ary)
    expect(ary2).to eq([2, 4])
  end

  it "does reject!" do
    ary = [1, 2, 3, 4]
    ary2 = ary.reject! { |x| x % 2 == 0 }
    expect(ary2).to be(ary)
    expect(ary2).to eq([1, 3])
  end

  it "does map_with_index" do
    ary = [1, 1, 2, 2]
    ary2 = ary.map_with_index { |e, i| e + i }
    expect(ary2).to eq([1, 2, 4, 5])
  end

  it "does + with different types (#568)" do
    a = [1, 2, 3]
    a += ["hello"]
    a.should eq([1, 2, 3, "hello"])
  end
end
