{% skip_file unless flag?(:unix) %}

require "spec"
require "../../../../src/crystal/system/unix/evented/arena"

describe Crystal::Evented::Arena do
  describe "#allocate_at?" do
    it "yields block when not allocated" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer = nil
      index = nil
      called = 0

      ret = arena.allocate_at?(0) do |ptr, idx|
        pointer = ptr
        index = idx
        called += 1
      end
      ret.should eq(index)
      called.should eq(1)

      ret = arena.allocate_at?(0) { called += 1 }
      ret.should be_nil
      called.should eq(1)

      pointer.should_not be_nil
      index.should_not be_nil

      arena.get(index.not_nil!) do |ptr|
        ptr.should eq(pointer)
      end
    end

    it "allocates up to capacity" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      indexes = [] of Crystal::Evented::Arena::Index

      indexes = 32.times.map do |i|
        arena.allocate_at?(i) { |ptr, _| ptr.value = i }
      end.to_a

      indexes.size.should eq(32)

      indexes.each do |index|
        arena.get(index.not_nil!) do |pointer|
          pointer.should eq(pointer)
          pointer.value.should eq(index.not_nil!.index)
        end
      end
    end

    it "checks bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      expect_raises(IndexError) { arena.allocate_at?(-1) { } }
      expect_raises(IndexError) { arena.allocate_at?(33) { } }
    end
  end

  describe "#get" do
    it "returns previously allocated object" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer = nil

      index = arena.allocate_at(30) do |ptr|
        pointer = ptr
        ptr.value = 654321
      end
      called = 0

      2.times do
        arena.get(index.not_nil!) do |ptr|
          ptr.should eq(pointer)
          ptr.value.should eq(654321)
          called += 1
        end
      end
      called.should eq(2)
    end

    it "can't access unallocated object" do
      arena = Crystal::Evented::Arena(Int32).new(32)

      expect_raises(RuntimeError) do
        arena.get(Crystal::Evented::Arena::Index.new(10, 0)) { }
      end
    end

    it "checks generation" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      index1 = arena.allocate_at(2) { called += 1 }
      called.should eq(1)

      arena.free(index1) { }
      expect_raises(RuntimeError) { arena.get(index1) { } }

      index2 = arena.allocate_at(2) { called += 1 }
      called.should eq(2)
      expect_raises(RuntimeError) { arena.get(index1) { } }

      arena.get(index2) { }
    end

    it "checks out of bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      expect_raises(IndexError) { arena.get(Crystal::Evented::Arena::Index.new(-1, 0)) { } }
      expect_raises(IndexError) { arena.get(Crystal::Evented::Arena::Index.new(33, 0)) { } }
    end
  end

  describe "#get?" do
    it "returns previously allocated object" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer = nil

      index = arena.allocate_at(30) do |ptr|
        pointer = ptr
        ptr.value = 654321
      end

      called = 0
      2.times do
        ret = arena.get?(index) do |ptr|
          ptr.should eq(pointer)
          ptr.not_nil!.value.should eq(654321)
          called += 1
        end
        ret.should be_true
      end
      called.should eq(2)
    end

    it "can't access unallocated index" do
      arena = Crystal::Evented::Arena(Int32).new(32)

      called = 0
      ret = arena.get?(Crystal::Evented::Arena::Index.new(10, 0)) { called += 1 }
      ret.should be_false
      called.should eq(0)
    end

    it "checks generation" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      old_index = arena.allocate_at(2) { }
      arena.free(old_index) { }

      # not accessible after free:
      ret = arena.get?(old_index) { called += 1 }
      ret.should be_false
      called.should eq(0)

      # can be reallocated:
      new_index = arena.allocate_at(2) { }

      # still not accessible after reallocate:
      ret = arena.get?(old_index) { called += 1 }
      ret.should be_false
      called.should eq(0)

      # accessible after reallocate (new index):
      ret = arena.get?(new_index) { called += 1 }
      ret.should be_true
      called.should eq(1)
    end

    it "checks out of bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      arena.get?(Crystal::Evented::Arena::Index.new(-1, 0)) { called += 1 }.should be_false
      arena.get?(Crystal::Evented::Arena::Index.new(33, 0)) { called += 1 }.should be_false

      called.should eq(0)
    end
  end

  describe "#free" do
    it "deallocates the object" do
      arena = Crystal::Evented::Arena(Int32).new(32)

      index1 = arena.allocate_at(3) { |ptr| ptr.value = 123 }
      arena.free(index1) { }

      index2 = arena.allocate_at(3) { }
      index2.should_not eq(index1)

      value = nil
      arena.get(index2) { |ptr| value = ptr.value }
      value.should eq(0)
    end

    it "checks generation" do
      arena = Crystal::Evented::Arena(Int32).new(32)

      called = 0
      old_index = arena.allocate_at(1) { }

      # can free:
      arena.free(old_index) { called += 1 }
      called.should eq(1)

      # can reallocate:
      new_index = arena.allocate_at(1) { }

      # can't free with invalid index:
      arena.free(old_index) { called += 1 }
      called.should eq(1)

      # but new index can:
      arena.free(new_index) { called += 1 }
      called.should eq(2)
    end

    it "checks out of bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      arena.free(Crystal::Evented::Arena::Index.new(-1, 0)) { called += 1 }
      arena.free(Crystal::Evented::Arena::Index.new(33, 0)) { called += 1 }

      called.should eq(0)
    end
  end
end
