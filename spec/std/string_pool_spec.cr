require "spec"
require "string_pool"

describe StringPool do
  it "is empty" do
    pool = StringPool.new
    pool.empty?.should be_true
    pool.length.should eq(0)
  end

  it "gets string" do
    pool = StringPool.new
    s1 = pool.get "foo"
    s2 = pool.get "foo"

    s1.should eq("foo")
    s2.should eq("foo")
    s1.object_id.should eq(s2.object_id)
    pool.length.should eq(1)
  end

  it "gets string IO" do
    pool = StringPool.new
    io = StringIO.new "foo"

    s1 = pool.get io
    s2 = pool.get "foo"

    s1.should eq("foo")
    s2.should eq("foo")
    s1.object_id.should eq(s2.object_id)
    pool.length.should eq(1)
  end

  it "gets slice" do
    pool = StringPool.new
    slice = Slice(UInt8).new(3, 'a'.ord.to_u8)

    s1 = pool.get(slice)
    s2 = pool.get(slice)

    s1.should eq("aaa")
    s2.should eq("aaa")
    s1.object_id.should eq(s2.object_id)
    pool.length.should eq(1)
  end

  it "gets pointer with length" do
    pool = StringPool.new
    slice = Slice(UInt8).new(3, 'a'.ord.to_u8)

    s1 = pool.get(slice.pointer(slice.length), slice.length)
    s2 = pool.get(slice.pointer(slice.length), slice.length)

    s1.should eq("aaa")
    s2.should eq("aaa")
    s1.object_id.should eq(s2.object_id)
    pool.length.should eq(1)
  end

  it "puts many" do
    pool = StringPool.new
    10_000.times do |i|
      pool.get(i.to_s)
    end
    pool.length.should eq(10_000)
  end
end
