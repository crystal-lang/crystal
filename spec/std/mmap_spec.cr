require "spec"
require "mmap"

struct MmapTestStruct
  property int, float

  def initialize @int : Int32, @float : Float64
  end
end

describe Mmap do
  it "mmaps UInt8" do
    foo = "foo"
    bar = "bar"

    Mmap(UInt8).open(size: 4096) do |mmap|
      mmap[4] = foo.to_slice
      mmap[8] = bar.to_slice
      String.new(mmap[4, 8]).should eq("foo\0bar\0")

      mmap[4095] = "a".to_slice
      expect_raises(ArgumentError) do
        mmap[4095] = "ab".to_slice
      end
    end
  end

  it "mmaps Int64" do
    Mmap(Int64).open(size: 2) do |mmap|
      mmap[1] = 1.to_i64
      mmap[1].should eq(1.to_i64)

      expect_raises(ArgumentError) do
        mmap[2] = 2.to_i64
      end
    end
  end

  it "mmaps a struct" do
    Mmap(MmapTestStruct).open(size: 2) do |mmap|
      st = MmapTestStruct.new 1, 2.0
      mmap[1] = st
      mmap[1].should eq(st)

      st.int += 1
      mmap[1].should_not eq(st)

      expect_raises(ArgumentError) do
        mmap[2] = st
      end
    end
  end
end
