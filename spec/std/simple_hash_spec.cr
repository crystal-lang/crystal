require "spec"
require "simple_hash"

describe "SimpleHash" do
  describe "[]" do
    it "returns the value corresponding to the given key" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      expect(a[1]).to eq(2)
      expect(a[3]).to eq(4)
      expect(a[5]).to eq(6)
      expect(a[7]).to eq(8)

      a = SimpleHash {one: :two, three: :four, five: :six}
      expect(a[:three]).to eq(:four)
    end

    it "raises on a missing key" do
      a = SimpleHash {one: :two, three: :four}
      expect_raises MissingKey do
        a[:five]
      end
    end
  end

  describe "[]?" do
    it "returns nil if the key is missing" do
      a = SimpleHash {"one": 1, "two": 2}
      expect(a["three"]?).to eq(nil)
      expect(a[:one]?).to eq(nil)
    end
  end

  describe "fetch" do
    it "returns the value corresponding to the given key, yields otherwise" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      expect(a.fetch(1) { 10 }).to eq(2)
      expect(a.fetch(3) { 10 }).to eq(4)
      expect(a.fetch(5) { 10 }).to eq(6)
      expect(a.fetch(7) { 10 }).to eq(8)
      expect(a.fetch(9) { 10 }).to eq(10)
    end
  end

  describe "[]=" do
    it "adds a new key-value pair if the key is missing" do
      a = SimpleHash(Int32, Int32).new
      a[1] = 2
      expect(a[1]).to eq(2)
    end

    it "replaces the value if the key already exists" do
      a = SimpleHash(Int32, Int32).new
      a[1] = 2
      a[1] = 3
      expect(a[1]).to eq(3)
    end
  end

  describe "has_key?" do
    it "returns true if the given key is present, false otherwise" do
      a = SimpleHash {"one": 1, "two": 2}
      expect(a.has_key?("one")).to be_true
      expect(a.has_key?("two")).to be_true
      expect(a.has_key?(:one)).to be_false
    end
  end

  describe "delete" do
    it "deletes the key-value pair corresponding to the given key" do
      a = SimpleHash {"one": 1, "two": 2}
      a.delete("two")
      expect(a["two"]?).to eq(nil)
      expect(a["one"]).to eq(1)
    end
  end

  describe "delete_if" do
    it "deletes {K, V} pairs when the block returns true" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.delete_if { |k, v| v > 4 }
      expect(a[1]?).to eq(2)
      expect(a[3]?).to eq(4)
      expect(a[5]?).to eq(nil)
      expect(a[7]?).to eq(nil)

      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.delete_if { |k, v| k < 4 }
      expect(a[1]?).to eq(nil)
      expect(a[3]?).to eq(nil)
      expect(a[5]?).to eq(6)
      expect(a[7]?).to eq(8)
    end
  end

  describe "dup" do
    it "returns a duplicate of the SimpleHash" do
      a = SimpleHash {"one": "1", "two": "2"}
      expect(a).to eq(a.dup)
    end
  end

  describe "each" do
    it "yields the key and value of each key-value pair" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      count = 0
      a.each { |k, v| count += k - v }
      expect(count).to eq(-4)

      count = 0
      a.each { |k, v| count += v - k }
      expect(count).to eq(4)
    end
  end

  describe "each_key" do
    it "yields every key" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      count = 0
      a.each_key { |k| count += k }
      expect(count).to eq(16)
    end
  end

  describe "each_value" do
    it "yields every value" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      count = 0
      a.each_value { |v| count += v }
      expect(count).to eq(20)
    end
  end

  describe "keys" do
    it "returns an array of all the keys" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      b = [1, 3, 5, 7]
      expect(a.keys).to eq(b)
    end
  end

  describe "values" do
    it "returns an array of all the values" do
      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      b = [2, 4, 6, 8]
      expect(a.values).to eq(b)
    end
  end

  describe "length" do
    it "returns the number of key-value pairs" do
      a = SimpleHash(Int32, Int32).new
      expect(a.length).to eq(0)

      a = SimpleHash {1 => 2}
      expect(a.length).to eq(1)

      a = SimpleHash {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      expect(a.length).to eq(4)
    end
  end

  describe "to_s" do
    it "returns a string representation" do
      a = SimpleHash(Int32, Int32).new
      expect(a.to_s).to eq("{}")

      a = SimpleHash {1 => 2}
      expect(a.to_s).to eq("{1 => 2}")

      a = SimpleHash {one: 1, two: 2, three: 3}
      expect(a.to_s).to eq("{:one => 1, :two => 2, :three => 3}")
    end
  end
end
