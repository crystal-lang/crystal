require "spec"
require "string_pool"

describe StringPool do
  it "is empty" do
    pool = StringPool.new
    expect(pool.empty?).to be_true
    expect(pool.length).to eq(0)
  end

  it "gets string" do
    pool = StringPool.new
    s1 = pool.get "foo"
    s2 = pool.get "foo"

    expect(s1).to eq("foo")
    expect(s2).to eq("foo")
    expect(s1.object_id).to eq(s2.object_id)
    expect(pool.length).to eq(1)
  end

  it "gets string IO" do
    pool = StringPool.new
    io = StringIO.new "foo"

    s1 = pool.get io
    s2 = pool.get "foo"

    expect(s1).to eq("foo")
    expect(s2).to eq("foo")
    expect(s1.object_id).to eq(s2.object_id)
    expect(pool.length).to eq(1)
  end

  it "gets slice" do
    pool = StringPool.new
    slice = Slice(UInt8).new(3, 'a'.ord.to_u8)

    s1 = pool.get(slice)
    s2 = pool.get(slice)

    expect(s1).to eq("aaa")
    expect(s2).to eq("aaa")
    expect(s1.object_id).to eq(s2.object_id)
    expect(pool.length).to eq(1)
  end

  it "gets pointer with length" do
    pool = StringPool.new
    slice = Slice(UInt8).new(3, 'a'.ord.to_u8)

    s1 = pool.get(slice.pointer(slice.length), slice.length)
    s2 = pool.get(slice.pointer(slice.length), slice.length)

    expect(s1).to eq("aaa")
    expect(s2).to eq("aaa")
    expect(s1.object_id).to eq(s2.object_id)
    expect(pool.length).to eq(1)
  end

  it "puts many" do
    pool = StringPool.new
    10_000.times do |i|
      pool.get(i.to_s)
    end
    expect(pool.length).to eq(10_000)
  end
end
