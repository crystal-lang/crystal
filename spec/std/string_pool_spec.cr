require "spec"
require "string_pool"

describe StringPool do
  it "is empty" do
    pool = StringPool.new
    pool.empty?.should be_true
    pool.size.should eq(0)
  end

  it "gets string" do
    pool = StringPool.new
    s1 = pool.get "foo"
    s2 = pool.get "foo"

    s1.should eq("foo")
    s2.should eq("foo")
    s1.should be(s2)
    pool.size.should eq(1)
  end

  it "gets string IO" do
    pool = StringPool.new
    io = IO::Memory.new "foo"

    s1 = pool.get io
    s2 = pool.get "foo"

    s1.should eq("foo")
    s2.should eq("foo")
    s1.should be(s2)
    pool.size.should eq(1)
  end

  it "gets slice" do
    pool = StringPool.new
    slice = Bytes.new(3, 'a'.ord.to_u8)

    s1 = pool.get(slice)
    s2 = pool.get(slice)

    s1.should eq("aaa")
    s2.should eq("aaa")
    s1.should be(s2)
    pool.size.should eq(1)
  end

  it "gets pointer with size" do
    pool = StringPool.new
    slice = Bytes.new(3, 'a'.ord.to_u8)

    s1 = pool.get(slice.to_unsafe, slice.size)
    s2 = pool.get(slice.to_unsafe, slice.size)

    s1.should eq("aaa")
    s2.should eq("aaa")
    s1.should be(s2)
    pool.size.should eq(1)
  end

  it "puts many" do
    pool = StringPool.new
    10_000.times do |i|
      pool.get(i.to_s)
    end
    pool.size.should eq(10_000)
  end

  it "can be created with larger initial capacity" do
    pool = StringPool.new(initial_capacity: 32)
    s1 = pool.get "foo"
    s2 = pool.get "foo"
    s1.should be(s2)
    pool.size.should eq(1)
  end

  it "doesn't fail if initial capacity is too small" do
    pool = StringPool.new(initial_capacity: 0)
    100.times do |i|
      pool.get(i.to_s)
    end
    pool.size.should eq(100)
  end

  it "doesn't fail if initial capacity is not a power of 2" do
    pool = StringPool.new(initial_capacity: 17)
    100.times do |i|
      pool.get(i.to_s)
    end
    pool.size.should eq(100)
  end
end
