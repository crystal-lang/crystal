require "spec"

class SpecEnumerable
  include Enumerable(Int32)

  def each
    yield 1
    yield 2
    yield 3
  end
end

describe "Enumerable" do
  describe "all? with block" do
    it "returns true" do
      ["ant", "bear", "cat"].all? { |word| word.size >= 3 }.should be_true
    end

    it "returns false" do
      ["ant", "bear", "cat"].all? { |word| word.size >= 4 }.should be_false
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

  describe "any? with block" do
    it "returns true if at least one element fulfills the condition" do
      ["ant", "bear", "cat"].any? { |word| word.size >= 4 }.should be_true
    end

    it "returns false if all elements dose not fulfill the condition" do
      ["ant", "bear", "cat"].any? { |word| word.size > 4 }.should be_false
    end
  end

  describe "any? without block" do
    it "returns true if at least one element is truthy" do
      [nil, true, 99].any?.should be_true
    end

    it "returns false if all elements are falsey" do
      [nil, false].any?.should be_false
    end
  end

  describe "compact map" do
    assert { Set{1, nil, 2, nil, 3}.compact_map { |x| x.try &.+(1) }.should eq([2, 3, 4]) }
  end

  describe "size without block" do
    it "returns the number of elements in the Enumerable" do
      SpecEnumerable.new.size.should eq 3
    end
  end

  describe "count with block" do
    it "returns the number of the times the item is present" do
      %w(a b c a d A).count("a").should eq 2
    end
  end

  describe "cycle" do
    it "calls forever if we don't break" do
      called = 0
      elements = [] of Int32
      (1..2).cycle do |e|
        elements << e
        called += 1
        break if called == 6
      end
      called.should eq 6
      elements.should eq [1, 2, 1, 2, 1, 2]
    end

    it "calls the block n times given the optional argument" do
      called = 0
      elements = [] of Int32
      (1..2).cycle(3) do |e|
        elements << e
        called += 1
      end
      called.should eq 6
      elements.should eq [1, 2, 1, 2, 1, 2]
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

  describe "each_with_index" do
    it "yields the element and the index" do
      collection = [] of {String, Int32}
      ["a", "b", "c"].each_with_index do |e, i|
        collection << {e, i}
      end
      collection.should eq [{"a", 0}, {"b", 1}, {"c", 2}]
    end

    it "accepts an optional offset parameter" do
      collection = [] of {String, Int32}
      ["Alice", "Bob"].each_with_index(1) do |e, i|
        collection << {e, i}
      end
      collection.should eq [{"Alice", 1}, {"Bob", 2}]
    end

    it "gets each_with_index iterator" do
      iter = [1, 2].each_with_index
      iter.next.should eq({1, 0})
      iter.next.should eq({2, 1})
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq({1, 0})
    end
  end

  describe "each_with_object" do
    it "yields the element and the given object" do
      collection = [] of {Int32, String}
      object = "a"
      (1..3).each_with_object(object) do |e, o|
        collection << {e, o}
      end
      collection.should eq [{1, object}, {2, object}, {3, object}]
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

  describe "first" do
    it "gets first" do
      (1..3).first.should eq(1)
    end

    it "raises if enumerable empty" do
      expect_raises Enumerable::EmptyError do
        (1...1).first
      end
    end

    assert { [-1, -2, -3].first.should eq(-1) }
  end

  describe "first?" do
    it "gets first?" do
      (1..3).first?.should eq(1)
    end

    it "returns nil if enumerable empty" do
      (1...1).first?.should be_nil
    end
  end

  describe "flat_map" do
    it "does example 1" do
      [1, 2, 3, 4].flat_map { |e| [e, -e] }.should eq([1, -1, 2, -2, 3, -3, 4, -4])
    end

    it "does example 2" do
      [[1, 2], [3, 4]].flat_map { |e| e + [100] }.should eq([1, 2, 100, 3, 4, 100])
    end
  end

  describe "grep" do
    it "works with regexes for instance" do
      ["Alice", "Bob", "Cipher", "Anna"].grep(/^A/).should eq ["Alice", "Anna"]
    end

    it "returns empty array if nothing matches" do
      %w(Alice Bob Mallory).grep(/nothing/).should eq [] of String
    end
  end

  describe "group_by" do
    assert { [1, 2, 2, 3].group_by { |x| x == 2 }.should eq({true => [2, 2], false => [1, 3]}) }

    it "groups can group by size (like the doc example)" do
      %w(Alice Bob Ary).group_by { |e| e.size }.should eq({3 => ["Bob", "Ary"],
        5 => ["Alice"]})
    end
  end

  describe "in_groups_of" do
    assert { [1, 2, 3].in_groups_of(1).should eq([[1], [2], [3]]) }
    assert { [1, 2, 3].in_groups_of(2).should eq([[1, 2], [3, nil]]) }
    assert { ([] of Int32).in_groups_of(2).should eq([] of Array(Array(Int32 | Nil))) }
    assert { [1, 2, 3].in_groups_of(2, "x").should eq([[1, 2], [3, "x"]]) }

    it "raises argument error if size is less than 0" do
      expect_raises ArgumentError, "size must be positive" do
        [1, 2, 3].in_groups_of(0)
      end
    end

    it "takes a block" do
      sums = [] of Int32
      [1, 2, 4].in_groups_of(2, 0) { |a| sums << a.sum }
      sums.should eq([3, 4])
    end
  end

  describe "includes?" do
    it "is true if the object exists in the collection" do
      [1, 2, 3].includes?(2).should be_true
    end

    it "is false if the object is not part of the collection" do
      [1, 2, 3].includes?(5).should be_false
    end
  end

  describe "index with a block" do
    it "returns the index of the first element where the blcok returns true" do
      ["Alice", "Bob"].index { |name| name.size < 4 }.should eq 1
    end

    it "returns nil if no object could be found" do
      ["Alice", "Bob"].index { |name| name.size < 3 }.should eq nil
    end
  end

  describe "index with an object" do
    it "returns the index of that object if found" do
      ["Alice", "Bob"].index("Alice").should eq 0
    end

    it "returns nil if the object was not found" do
      ["Alice", "Bob"].index("Mallory").should be_nil
    end
  end

  describe "index_by" do
    it "creates a hash indexed by the value returned by the block" do
      hash = ["Anna", "Ary", "Alice"].index_by { |e| e.size }
      hash.should eq({4 => "Anna", 3 => "Ary", 5 => "Alice"})
    end

    it "overrides values if a value is returned twice" do
      hash = ["Anna", "Ary", "Alice", "Bob"].index_by { |e| e.size }
      hash.should eq({4 => "Anna", 3 => "Bob", 5 => "Alice"})
    end
  end

  describe "reduce" do
    assert { [1, 2, 3].reduce { |memo, i| memo + i }.should eq(6) }
    assert { [1, 2, 3].reduce(10) { |memo, i| memo + i }.should eq(16) }

    it "raises if empty" do
      expect_raises Enumerable::EmptyError do
        ([] of Int32).reduce { |memo, i| memo + i }
      end
    end

    it "does not raise if empty if there is a memo argument" do
      result = ([] of Int32).reduce(10) { |memo, i| memo + i }
      result.should eq 10
    end
  end

  describe "join" do
    it "joins with separator and block" do
      str = [1, 2, 3].join(", ") { |x| x + 1 }
      str.should eq("2, 3, 4")
    end

    it "joins without separator and block" do
      str = [1, 2, 3].join { |x| x + 1 }
      str.should eq("234")
    end

    it "joins with io and block" do
      str = MemoryIO.new
      [1, 2, 3].join(", ", str) { |x, io| io << x + 1 }
      str.to_s.should eq("2, 3, 4")
    end

    it "joins with only separator" do
      ["Ruby", "Crystal", "Python"].join(", ").should eq "Ruby, Crystal, Python"
    end
  end

  describe "map" do
    it "applies the function to each element and returns a new array" do
      result = [1, 2, 3].map { |i| i * 10 }
      result.should eq [10, 20, 30]
    end

    it "leaves the original unmodified" do
      original = [1, 2, 3]
      original.map { |i| i * 10 }
      original.should eq [1, 2, 3]
    end
  end

  describe "map_with_index" do
    it "yields the element and the index" do
      result = ["Alice", "Bob"].map_with_index { |name, i| "User ##{i}: #{name}" }
      result.should eq ["User #0: Alice", "User #1: Bob"]
    end
  end

  describe "max" do
    assert { [1, 2, 3].max.should eq(3) }

    it "raises if empty" do
      expect_raises Enumerable::EmptyError do
        ([] of Int32).max
      end
    end
  end

  describe "max?" do
    it "returns nil if empty" do
      ([] of Int32).max?.should be_nil
    end
  end

  describe "max_by" do
    assert { [-1, -2, -3].max_by { |x| -x }.should eq(-3) }
  end

  describe "max_by?" do
    it "returns nil if empty" do
      ([] of Int32).max_by? { |x| -x }.should be_nil
    end
  end

  describe "max_of" do
    assert { [-1, -2, -3].max_of { |x| -x }.should eq(3) }
  end

  describe "max_of?" do
    it "returns nil if empty" do
      ([] of Int32).max_of? { |x| -x }.should be_nil
    end
  end

  describe "min" do
    assert { [1, 2, 3].min.should eq(1) }

    it "raises if empty" do
      expect_raises Enumerable::EmptyError do
        ([] of Int32).min
      end
    end
  end

  describe "min?" do
    it "returns nil if empty" do
      ([] of Int32).min?.should be_nil
    end
  end

  describe "min_by" do
    assert { [1, 2, 3].min_by { |x| -x }.should eq(3) }
  end

  describe "min_by?" do
    it "returns nil if empty" do
      ([] of Int32).max_by? { |x| -x }.should be_nil
    end
  end

  describe "min_of" do
    assert { [1, 2, 3].min_of { |x| -x }.should eq(-3) }
  end

  describe "min_of?" do
    it "returns nil if empty" do
      ([] of Int32).min_of? { |x| -x }.should be_nil
    end
  end

  describe "minmax" do
    assert { [1, 2, 3].minmax.should eq({1, 3}) }

    it "raises if empty" do
      expect_raises Enumerable::EmptyError do
        ([] of Int32).minmax
      end
    end
  end

  describe "minmax?" do
    it "returns two nils if empty" do
      ([] of Int32).minmax?.should eq({nil, nil})
    end
  end

  describe "minmax_by" do
    assert { [-1, -2, -3].minmax_by { |x| -x }.should eq({-1, -3}) }
  end

  describe "minmax_by?" do
    it "returns two nils if empty" do
      ([] of Int32).minmax_by? { |x| -x }.should eq({nil, nil})
    end
  end

  describe "minmax_of" do
    assert { [-1, -2, -3].minmax_of { |x| -x }.should eq({1, 3}) }
  end

  describe "minmax_of?" do
    it "returns two nils if empty" do
      ([] of Int32).minmax_of? { |x| -x }.should eq({nil, nil})
    end
  end

  describe "none?" do
    assert { [1, 2, 2, 3].none? { |x| x == 1 }.should eq(false) }
    assert { [1, 2, 2, 3].none? { |x| x == 0 }.should eq(true) }
  end

  describe "none? without block" do
    assert { [nil, false].none?.should be_true }
    assert { [nil, false, true].none?.should be_false }
  end

  describe "one?" do
    assert { [1, 2, 2, 3].one? { |x| x == 1 }.should eq(true) }
    assert { [1, 2, 2, 3].one? { |x| x == 2 }.should eq(false) }
    assert { [1, 2, 2, 3].one? { |x| x == 0 }.should eq(false) }
  end

  describe "partition" do
    assert { [1, 2, 2, 3].partition { |x| x == 2 }.should eq({[2, 2], [1, 3]}) }
    assert { [1, 2, 3, 4, 5, 6].partition(&.even?).should eq({[2, 4, 6], [1, 3, 5]}) }
  end

  describe "reject" do
    it "rejects the values for which the block returns true" do
      [1, 2, 3, 4].reject(&.even?).should eq([1, 3])
    end
  end

  describe "select" do
    it "selects the values for which the block returns true" do
      [1, 2, 3, 4].select(&.even?).should eq([2, 4])
    end
  end

  describe "skip" do
    it "returns an array without the skipped elements" do
      [1, 2, 3, 4, 5, 6].skip(3).should eq [4, 5, 6]
    end

    it "returns an empty array when skipping more elements than array size" do
      [1, 2].skip(3).should eq [] of Int32
    end

    it "raises if count is negative" do
      expect_raises(ArgumentError) do
        [1, 2].skip(-1)
      end
    end
  end

  describe "skip_while" do
    it "skips elements while the condition holds true" do
      result = [1, 2, 3, 4, 5, 0].skip_while { |i| i < 3 }
      result.should eq [3, 4, 5, 0]
    end

    it "returns an empty array if the condition is always true" do
      [1, 2, 3].skip_while { true }.should eq [] of Int32
    end

    it "returns the full Array if the the first check is false" do
      [5, 0, 1, 2, 3].skip_while { |x| x < 4 }.should eq [5, 0, 1, 2, 3]
    end

    it "does not yield to the block anymore once it returned false" do
      called = 0
      [1, 2, 3, 4, 4].skip_while do |i|
        called += 1
        i < 3
      end
      called.should eq 3
    end
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

  describe "first" do
    assert { (1..3).first(1).should eq([1]) }
    assert { (1..3).first(4).should eq([1, 2, 3]) }

    it "raises if count is negative" do
      expect_raises(ArgumentError) do
        (1..2).first(-1)
      end
    end
  end

  describe "take_while" do
    it "keeps elements while the block returns true" do
      [1, 2, 3, 4, 5, 0].take_while { |i| i < 3 }.should eq [1, 2]
    end

    it "returns the full Array if the condition is always true" do
      [1, 2, 3, -3].take_while { true }.should eq [1, 2, 3, -3]
    end

    it "returns an empty Array if the block is false for the first element" do
      [1, 2, -1, 0].take_while { |i| i <= 0 }.should eq [] of Int32
    end

    it "does not call the block again once it returned false" do
      called = 0
      [1, 2, 3, 4, 0].take_while do |i|
        called += 1
        i < 3
      end
      called.should eq 3
    end
  end

  describe "to_a" do
    it "converts to an Array" do
      (1..3).to_a.should eq [1, 2, 3]
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
end
