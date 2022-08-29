require "spec"
require "../../../src/compiler/crystal/zero_one_or_many"

describe Crystal::ZeroOneOrMany do
  describe "initialize and size" do
    it "creates without a value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary.size.should eq(0)
      ary.value.should be_nil
    end

    it "creates with a value" do
      ary = Crystal::ZeroOneOrMany.new(1)
      ary.size.should eq(1)
      ary.to_a.should eq([1])
      ary.value.should be_a(Int32)
    end

    it "creates with an empty array" do
      ary = Crystal::ZeroOneOrMany.new([] of Int32)
      ary.size.should eq(0)
      ary.value.should be_nil
    end

    it "creates with an array of one value" do
      ary = Crystal::ZeroOneOrMany.new([1])
      ary.size.should eq(1)
      ary.to_a.should eq([1])
      ary.value.should be_a(Int32)
    end

    it "creates with an array of more than one value" do
      elements = [1, 2, 3]

      ary = Crystal::ZeroOneOrMany.new(elements)
      ary.size.should eq(3)
      ary.to_a.should eq([1, 2, 3])
      ary.value.should be_a(Array(Int32))

      # Mutating the original array changes ZeroOneOrMany,
      # but this is according to the type's description.
      elements.pop
      ary.to_a.should eq([1, 2])
    end
  end

  describe "as Indexable" do
    it "when there's no value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      expect_raises(IndexError) { ary[0] }
      expect_raises(IndexError) { ary[1] }
    end

    it "when there's a single value" do
      ary = Crystal::ZeroOneOrMany.new(1)
      ary[0].should eq(1)
      expect_raises(IndexError) { ary[1] }
    end

    it "when there's two values" do
      ary = Crystal::ZeroOneOrMany.new([1, 2])
      ary[0].should eq(1)
      ary[1].should eq(2)
      expect_raises(IndexError) { ary[2] }
    end
  end

  describe "#each" do
    it "when there's no value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary.sum.should eq(0)
    end

    it "when there's a single value" do
      ary = Crystal::ZeroOneOrMany.new(1)
      ary.sum.should eq(1)
    end

    it "when there's two values" do
      ary = Crystal::ZeroOneOrMany.new([1, 2])
      ary.sum.should eq(3)
    end
  end

  describe "#+ element" do
    it "when there's no value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary += 1
      ary.to_a.should eq([1])
    end

    it "when there's a single value" do
      ary = Crystal::ZeroOneOrMany.new(1)
      ary += 2
      ary.to_a.should eq([1, 2])
    end

    it "when there's two values" do
      elements = [1, 2]

      ary = Crystal::ZeroOneOrMany.new(elements)
      ary += 3
      ary.to_a.should eq([1, 2, 3])

      # Elements was also mutated, but this is expected
      # according to the type's description.
      elements.should eq([1, 2, 3])
    end
  end

  describe "#+ elements" do
    it "when there's no value and elements is empty" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary += [] of Int32
      ary.empty?.should be_true
      ary.value.should be_nil
    end

    it "when there's no value and elements has a single value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary += [1]
      ary.to_a.should eq([1])
      ary.value.should be_a(Int32)
    end

    it "when there's no value and elements has more than one value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary += [1, 2]
      ary.to_a.should eq([1, 2])
      ary.value.should be_a(Array(Int32))
    end

    it "when there's a single value" do
      ary = Crystal::ZeroOneOrMany.new(1)
      ary += [2, 3]
      ary.to_a.should eq([1, 2, 3])
      ary.value.should be_a(Array(Int32))
    end

    it "when there's two values" do
      ary = Crystal::ZeroOneOrMany.new([1, 2])
      ary += [3, 4]
      ary.to_a.should eq([1, 2, 3, 4])
      ary.value.should be_a(Array(Int32))
    end
  end

  describe "#reject" do
    it "when there's no value" do
      ary = Crystal::ZeroOneOrMany(Int32).new
      ary = ary.reject { true }
      ary.empty?.should be_true
      ary.value.should be_nil
    end

    it "when there's a single value and it matches" do
      ary = Crystal::ZeroOneOrMany(Int32).new(1)
      ary = ary.reject { |x| x == 1 }
      ary.empty?.should be_true
      ary.value.should be_nil
    end

    it "when there's a single value and it doesn't match" do
      ary = Crystal::ZeroOneOrMany(Int32).new(1)
      ary = ary.reject { |x| x == 2 }
      ary.to_a.should eq([1])
      ary.value.should be_a(Int32)
    end

    it "when there are three values and none matches" do
      ary = Crystal::ZeroOneOrMany(Int32).new([1, 2, 3])
      ary = ary.reject { |x| x == 4 }
      ary.to_a.should eq([1, 2, 3])
      ary.value.should be_a(Array(Int32))
    end

    it "when there are three values and two match" do
      elements = [1, 2, 3]

      ary = Crystal::ZeroOneOrMany(Int32).new(elements)
      ary = ary.reject { |x| x < 3 }
      ary.to_a.should eq([3])
      ary.value.should be_a(Int32)

      # Note: elements is also mutated.
      # This is fine: the owner of elements becomes ZeroOneOrMany
      # per the type's description.
      elements.should eq([3])
    end

    it "when there are three values and all match" do
      elements = [1, 2, 3]

      ary = Crystal::ZeroOneOrMany(Int32).new(elements)
      ary = ary.reject { |x| x < 4 }
      ary.empty?.should be_true
      ary.value.should be_nil

      # Note: elements is also mutated.
      # This is fine: the owner of elements becomes ZeroOneOrMany
      # per the type's description.
      elements.empty?.should be_true
    end
  end
end
