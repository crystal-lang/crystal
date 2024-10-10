{% skip_file unless flag?(:unix) %}

require "spec"
require "../../../../src/crystal/system/unix/evented/arena"

describe Crystal::Evented::Arena do
  describe "#lazy_allocate" do
    it "yields block once" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer = nil
      index = nil
      called = 0

      ptr1, idx1 = arena.lazy_allocate(0) do |ptr, idx|
        pointer = ptr
        index = idx
        called += 1
      end
      called.should eq(1)

      ptr2, idx2 = arena.lazy_allocate(0) do |ptr, idx|
        called += 1
      end
      called.should eq(1)

      pointer.should_not be_nil
      index.should_not be_nil

      ptr1.should eq(pointer)
      idx1.should eq(index)

      ptr2.should eq(pointer)
      idx2.should eq(index)
    end

    it "allocates up to capacity" do
      arena = Crystal::Evented::Arena(Int32).new(32)

      objects = 32.times.map do |i|
        arena.lazy_allocate(i) { |pointer| pointer.value = i }
      end
      objects.each do |(pointer, index)|
        arena.get(index).should eq(pointer)
        pointer.value.should eq(index.index)
      end
    end

    it "checks bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      expect_raises(IndexError) { arena.lazy_allocate(-1) {} }
      expect_raises(IndexError) { arena.lazy_allocate(33) {} }
    end
  end

  describe "#get" do
    it "returns previously allocated object" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer, index = arena.lazy_allocate(30) { |ptr| ptr.value = 654321 }

      2.times do
        ptr = arena.get(index)
        ptr.should eq(pointer)
        ptr.value.should eq(654321)
      end

      # not allocated:
      expect_raises(RuntimeError) do
        arena.get(Crystal::Evented::Arena::Index.new(10, 0))
      end
    end

    it "checks generation" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      _, index1 = arena.lazy_allocate(2) { called += 1 }
      called.should eq(1)

      arena.free(index1) { }
      expect_raises(RuntimeError) { arena.get(index1) }

      _, index2 = arena.lazy_allocate(2) { called += 1 }
      called.should eq(2)
      expect_raises(RuntimeError) { arena.get(index1) }

      # doesn't raise:
      arena.get(index2)
    end

    it "checks out of bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      expect_raises(IndexError) { arena.get(Crystal::Evented::Arena::Index.new(-1, 0)) }
      expect_raises(IndexError) { arena.get(Crystal::Evented::Arena::Index.new(33, 0)) }
    end
  end

  describe "#get?" do
    it "returns previously allocated object" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer, index = arena.lazy_allocate(30) { |ptr| ptr.value = 654321 }

      2.times do
        ptr = arena.get?(index)
        ptr.should eq(pointer)
        ptr.not_nil!.value.should eq(654321)
      end

      arena.get?(Crystal::Evented::Arena::Index.new(10, 0)).should be_nil
    end

    it "checks generation" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      pointer1, index1 = arena.lazy_allocate(2) { called += 1 }
      called.should eq(1)

      arena.free(index1) { }
      arena.get?(index1).should be_nil

      pointer2, index2 = arena.lazy_allocate(2) { called += 1 }
      called.should eq(2)
      arena.get?(index1).should be_nil
      arena.get?(index2).should eq(pointer2)
    end

    it "checks out of bounds" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      arena.get?(Crystal::Evented::Arena::Index.new(-1, 0)).should be_nil
      arena.get?(Crystal::Evented::Arena::Index.new(33, 0)).should be_nil
    end
  end

  describe "#free" do
    it "deallocates the object" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      pointer, index1 = arena.lazy_allocate(3) { }
      pointer.value = 123

      arena.free(index1) { }

      pointer, index2 = arena.lazy_allocate(3) { }
      index2.should_not eq(index1)
      pointer.value.should eq(0)
    end

    it "checks generation" do
      arena = Crystal::Evented::Arena(Int32).new(32)
      called = 0

      _, index1 = arena.lazy_allocate(1) { }
      arena.free(index1) { called += 1}
      called.should eq(1)

      _, index2 = arena.lazy_allocate(1) { }
      arena.free(index1) { called += 1 }
      called.should eq(1)

      arena.free(index2) { called += 1 }
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
