require "spec"

describe "Slice" do
  it "gets pointer and length" do
    pointer = Pointer.malloc(1, 0)
    slice = Slice.new(pointer, 1)
    slice.pointer(0).should eq(pointer)
    slice.length.should eq(1)
  end

  it "does []" do
    slice = Slice.new(3) { |i| i + 1 }
    3.times do |i|
      slice[i].should eq(i + 1)
    end
    slice[-1].should eq(3)
    slice[-2].should eq(2)
    slice[-3].should eq(1)

    expect_raises(IndexError) { slice[-4] }
    expect_raises(IndexError) { slice[3] }
  end

  it "does []=" do
    slice = Slice.new(3, 0)
    slice[0] = 1
    slice[0].should eq(1)

    expect_raises(IndexError) { slice[-4] = 1 }
    expect_raises(IndexError) { slice[3] = 1 }
  end

  it "does +" do
    slice = Slice.new(3) { |i| i + 1}

    slice1 = slice + 1
    slice1.length.should eq(2)
    slice1[0].should eq(2)
    slice1[1].should eq(3)

    slice3 = slice + 3
    slice3.length.should eq(0)

    expect_raises(IndexError) { slice + 4 }
    expect_raises(IndexError) { slice + (-1) }
  end

  it "does [] with start and count" do
    slice = Slice.new(4) { |i| i + 1}
    slice1 = slice[1, 2]
    slice1.length.should eq(2)
    slice1[0].should eq(2)
    slice1[1].should eq(3)

    expect_raises(IndexError) { slice[-1, 1] }
    expect_raises(IndexError) { slice[3, 2] }
    expect_raises(IndexError) { slice[0, 5] }
    expect_raises(IndexError) { slice[3, -1] }
  end

  it "does empty?" do
    Slice.new(0, 0).empty?.should be_true
    Slice.new(1, 0).empty?.should be_false
  end

  it "raises if length is negative on new" do
    expect_raises(ArgumentError) { Slice.new(-1, 0) }
  end

  it "does to_s" do
    slice = Slice.new(4) { |i| i + 1}
    slice.to_s.should eq("[1, 2, 3, 4]")
  end

  it "gets pointer" do
    slice = Slice.new(4, 0)
    expect_raises(IndexError) { slice.pointer(5) }
    expect_raises(IndexError) { slice.pointer(-1) }
  end

  it "does copy_from" do
    pointer = Pointer.malloc(4) { |i| i + 1 }
    slice = Slice.new(4, 0)
    slice.copy_from(pointer, 4)
    4.times { |i| slice[i].should eq(i + 1) }

    expect_raises(IndexError) { slice.copy_from(pointer, 5) }
  end

  it "does copy_to" do
    pointer = Pointer.malloc(4, 0)
    slice = Slice.new(4) { |i| i + 1 }
    slice.copy_to(pointer, 4)
    4.times { |i| pointer[i].should eq(i + 1) }

    expect_raises(IndexError) { slice.copy_to(pointer, 5) }
  end

  it "does hexstring" do
    slice = Slice(UInt8).new(4) { |i| i.to_u8 + 1 }
    slice.hexstring.should eq("01020304")
  end

  it "does iterator" do
    slice = Slice(Int32).new(3) { |i| i + 1 }
    iter = slice.each
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(1)
  end

  it "does to_a" do
    slice = Slice.new(3) { |i| i }
    ary = slice.to_a
    ary.should eq([0, 1, 2])
  end

  it "does rindex" do
    slice = "foobar".to_slice
    slice.rindex('o'.ord.to_u8).should eq(2)
    slice.rindex('z'.ord.to_u8).should be_nil
  end
end
