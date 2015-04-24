require "spec"

describe "Slice" do
  it "gets pointer and length" do
    pointer = Pointer.malloc(1, 0)
    slice = Slice.new(pointer, 1)
    expect(slice.pointer(0)).to eq(pointer)
    expect(slice.length).to eq(1)
  end

  it "does []" do
    slice = Slice.new(3) { |i| i + 1 }
    3.times do |i|
      expect(slice[i]).to eq(i + 1)
    end
    expect(slice[-1]).to eq(3)
    expect(slice[-2]).to eq(2)
    expect(slice[-3]).to eq(1)

    expect_raises(IndexOutOfBounds) { slice[-4] }
    expect_raises(IndexOutOfBounds) { slice[3] }
  end

  it "does []=" do
    slice = Slice.new(3, 0)
    slice[0] = 1
    expect(slice[0]).to eq(1)

    expect_raises(IndexOutOfBounds) { slice[-4] = 1 }
    expect_raises(IndexOutOfBounds) { slice[3] = 1 }
  end

  it "does +" do
    slice = Slice.new(3) { |i| i + 1}

    slice1 = slice + 1
    expect(slice1.length).to eq(2)
    expect(slice1[0]).to eq(2)
    expect(slice1[1]).to eq(3)

    slice3 = slice + 3
    expect(slice3.length).to eq(0)

    expect_raises(IndexOutOfBounds) { slice + 4 }
    expect_raises(IndexOutOfBounds) { slice + (-1) }
  end

  it "does [] with start and count" do
    slice = Slice.new(4) { |i| i + 1}
    slice1 = slice[1, 2]
    expect(slice1.length).to eq(2)
    expect(slice1[0]).to eq(2)
    expect(slice1[1]).to eq(3)

    expect_raises(IndexOutOfBounds) { slice[-1, 1] }
    expect_raises(IndexOutOfBounds) { slice[3, 2] }
    expect_raises(IndexOutOfBounds) { slice[0, 5] }
    expect_raises(IndexOutOfBounds) { slice[3, -1] }
  end

  it "does empty?" do
    expect(Slice.new(0, 0).empty?).to be_true
    expect(Slice.new(1, 0).empty?).to be_false
  end

  it "raises if length is negative on new" do
    expect_raises(ArgumentError) { Slice.new(-1, 0) }
  end

  it "does to_s" do
    slice = Slice.new(4) { |i| i + 1}
    expect(slice.to_s).to eq("[1, 2, 3, 4]")
  end

  it "gets pointer" do
    slice = Slice.new(4, 0)
    expect_raises(IndexOutOfBounds) { slice.pointer(5) }
    expect_raises(IndexOutOfBounds) { slice.pointer(-1) }
  end

  it "does copy_from" do
    pointer = Pointer.malloc(4) { |i| i + 1 }
    slice = Slice.new(4, 0)
    slice.copy_from(pointer, 4)
    4.times { |i| expect(slice[i]).to eq(i + 1) }

    expect_raises(IndexOutOfBounds) { slice.copy_from(pointer, 5) }
  end

  it "does copy_to" do
    pointer = Pointer.malloc(4, 0)
    slice = Slice.new(4) { |i| i + 1 }
    slice.copy_to(pointer, 4)
    4.times { |i| expect(pointer[i]).to eq(i + 1) }

    expect_raises(IndexOutOfBounds) { slice.copy_to(pointer, 5) }
  end

  it "does hexstring" do
    slice = Slice(UInt8).new(4) { |i| i.to_u8 + 1 }
    expect(slice.hexstring).to eq("01020304")
  end
end
