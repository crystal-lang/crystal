require "spec"

describe Enumerable::FixedSizeCompare do
  describe "common classes that include iterable" do
    describe "==" do
      it "compares arrays" do
        a = [0, 1, 2]
        b = [0, 1, 2]
        c = [0, 1]
        d = [0, 1, 2, 3]
        e = [4, 5, 6]
        a.should eq(b)
        a.should_not eq(c)
        a.should_not eq(d)
        a.should_not eq(e)
      end

      it "compares static arrays" do
        a = StaticArray(Int32, 3).new { |i| i }
        b = StaticArray(Int16, 3).new { |i| Int16.new(i) }
        c = StaticArray(Int32, 2).new { |i| i }
        d = StaticArray(Int32, 4).new { |i| i }
        e = StaticArray(Int32, 3).new { |i| i + 1 }
        a.should eq(b)
        a.should_not eq(c)
        a.should_not eq(d)
        a.should_not eq(e)
      end

      it "compares slices" do
        a = Slice.new(3) { |i| i }
        b = Slice.new(3) { |i| i }
        c = Slice.new(2) { |i| i }
        d = Slice.new(4) { |i| i }
        e = Slice.new(3) { |i| i + 1 }
        a.should eq(b)
        a.should_not eq(c)
        a.should_not eq(d)
        a.should_not eq(e)
      end

      it "compares between types" do
        a = [0, 1, 2]
        b = StaticArray(Int32, 3).new { |i| i }
        c = Slice.new(3) { |i| i }

        a.should eq(b)
        a.should eq(c)

        b.should eq(a)
        b.should eq(c)

        c.should eq(a)
        c.should eq(b)
      end

      it "compares UInt8" do # optimized with memcmp
        a = StaticArray(UInt8, 3).new { |i| UInt8.new(i) }
        b = StaticArray(UInt8, 3).new { |i| UInt8.new(i) }
        c = StaticArray(UInt8, 3).new { |i| UInt8.new(i + 1) }

        a.should eq(b)
        a.should_not eq(c)
      end

      it "compares nested types" do
        a = [
          Slice.new(3) { |i|
            StaticArray(Tuple(Array(Int32), Array(Int32)), 3).new { |j| {[i, j], [j, i]} }
          }
        ]
        b = [
          Slice.new(3) { |i|
            StaticArray(Tuple(Array(Int32), Array(Int32)), 3).new { |j| {[i, j], [j, i]} }
          }
        ]
        c = [
          Slice.new(3) { |i|
            # end array is larger
            StaticArray(Tuple(Array(Int32), Array(Int32)), 3).new { |j| {[i, j], [j, i, 0]} }
          }
        ]

        a.should eq(b)
        a.should_not eq(c)
      end
    end
  end
end

