require "spec"
require "simple_hash"

describe "SimpleHash" do
  describe "[]" do
    it "returns the value corresponding to the given key" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a[1].should eq(2)
      a[3].should eq(4)
      a[5].should eq(6)
      a[7].should eq(8)

      a = SimpleHash {one: :two, three: :four, five: :six}
      a[:three].should eq(:four)
    end

    it "raises on a missing key" do
      a = SimpleHash {one: :two, three: :four}
      expect_raises KeyError do
        a[:five]
      end
    end
  end

  describe "[]?" do
    it "returns nil if the key is missing" do
      a = SimpleHash {"one": 1, "two": 2}
      a["three"]?.should eq(nil)
      a[:one]?.should eq(nil)
    end
  end

  describe "fetch" do
    it "returns the value corresponding to the given key, yields otherwise" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.fetch(1) { 10 }.should eq(2)
      a.fetch(3) { 10 }.should eq(4)
      a.fetch(5) { 10 }.should eq(6)
      a.fetch(7) { 10 }.should eq(8)
      a.fetch(9) { 10 }.should eq(10)
    end
  end

  describe "[]=" do
    it "adds a new key-value pair if the key is missing" do
      a = SimpleHash(Int32, Int32).new
      a[1] = 2
      a[1].should eq(2)
    end

    it "replaces the value if the key already exists" do
      a = SimpleHash(Int32, Int32).new
      a[1] = 2
      a[1] = 3
      a[1].should eq(3)
    end
  end

  describe "has_key?" do
    it "returns true if the given key is present, false otherwise" do
      a = SimpleHash {"one": 1, "two": 2}
      a.has_key?("one").should be_true
      a.has_key?("two").should be_true
      a.has_key?(:one).should be_false
    end
  end

  describe "delete" do
    it "deletes the key-value pair corresponding to the given key" do
      a = SimpleHash {"one": 1, "two": 2}
      a.delete("two")
      a["two"]?.should eq(nil)
      a["one"].should eq(1)
    end
  end

  describe "delete_if" do
    it "deletes {K, V} pairs when the block returns true" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.delete_if { |k, v| v > 4 }
      a[1]?.should eq(2)
      a[3]?.should eq(4)
      a[5]?.should eq(nil)
      a[7]?.should eq(nil)

      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.delete_if { |k, v| k < 4 }
      a[1]?.should eq(nil)
      a[3]?.should eq(nil)
      a[5]?.should eq(6)
      a[7]?.should eq(8)
    end
  end

  describe "dup" do
    it "returns a duplicate of the SimpleHash" do
      a = SimpleHash {"one": "1", "two": "2"}
      a.should eq(a.dup)
    end
  end

  describe "each" do
    it "yields the key and value of each key-value pair" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      count = 0
      a.each { |k, v| count += k - v }
      count.should eq(-4)

      count = 0
      a.each { |k, v| count += v - k }
      count.should eq(4)
    end
  end

  describe "each_key" do
    it "yields every key" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      count = 0
      a.each_key { |k| count += k }
      count.should eq(16)
    end
  end

  describe "each_value" do
    it "yields every value" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      count = 0
      a.each_value { |v| count += v }
      count.should eq(20)
    end
  end

  describe "keys" do
    it "returns an array of all the keys" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      b = [1, 3, 5, 7]
      a.keys.should eq(b)
    end
  end

  describe "values" do
    it "returns an array of all the values" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      b = [2, 4, 6, 8]
      a.values.should eq(b)
    end
  end

  describe "length" do
    it "returns the number of key-value pairs" do
      a = SimpleHash(Int32, Int32).new
      a.length.should eq(0)

      a = SimpleHash {1 => 2}
      a.length.should eq(1)

      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.length.should eq(4)
    end
  end

  describe "size" do
    it "is the same as #length" do
      a = SimpleHash(Int32, Int32).new
      a.size.should eq(a.length)

      a = SimpleHash {1 => 2}
      a.size.should eq(a.length)

      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.size.should eq(a.length)
    end
  end

  describe "to_s" do
    it "returns a string representation" do
      a = SimpleHash(Int32, Int32).new
      a.to_s.should eq("{}")

      a = SimpleHash {1 => 2}
      a.to_s.should eq("{1 => 2}")

      a = SimpleHash {one: 1, two: 2, three: 3}
      a.to_s.should eq("{:one => 1, :two => 2, :three => 3}")
    end
  end
end
