require "spec"
require "bit_array"

describe "BitArray" do
  it "has size" do
    ary = BitArray.new(100)
    ary.size.should eq(100)
  end

  it "is initially empty" do
    ary = BitArray.new(100)
    100.times do |i|
      ary[i].should be_false
    end
  end

  it "sets first bit to true" do
    ary = BitArray.new(100)
    ary[0] = true
    ary[0].should be_true
  end

  it "sets second bit to true" do
    ary = BitArray.new(100)
    ary[1] = true
    ary[1].should be_true
  end

  it "sets first bit to false" do
    ary = BitArray.new(100)
    ary[0] = true
    ary[0] = false
    ary[0].should be_false
  end

  it "sets second bit to false" do
    ary = BitArray.new(100)
    ary[1] = true
    ary[1] = false
    ary[1].should be_false
  end

  it "sets last bit to true with negative index" do
    ary = BitArray.new(100)
    ary[-1] = true
    ary[-1].should be_true
    ary[99].should be_true
  end

  it "toggles a bit" do
    ary = BitArray.new(32)
    ary[3].should be_false

    ary.toggle(3)
    ary[3].should be_true

    ary.toggle(3)
    ary[3].should be_false
  end

  it "inverts all bits" do
    ary = BitArray.new(100)
    ary.none?.should be_true

    ary.invert
    ary.all?.should be_true

    ary[50] = false
    ary[33] = false
    ary.count { |b| b }.should eq(98)

    ary.invert
    ary.count { |b| b }.should eq(2)
  end

  it "raises when out of bounds" do
    ary = BitArray.new(10)
    expect_raises IndexError do
      ary[10] = true
    end
  end

  it "does to_s and inspect" do
    ary = BitArray.new(8)
    ary[0] = true
    ary[2] = true
    ary[4] = true
    ary.to_s.should eq("BitArray[10101000]")
    ary.inspect.should eq("BitArray[10101000]")
  end

  it "initializes with true by default" do
    ary = BitArray.new(64, true)
    ary.size.times { |i| ary[i].should be_true }
  end

  it "reads bits from slice" do
    ary = BitArray.new(43) # 5 bytes 3 bits
    # 11010000_00000000_00001011_00000000_00000000_101xxxxx
    ary[0] = true
    ary[1] = true
    ary[3] = true
    ary[20] = true
    ary[22] = true
    ary[23] = true
    ary[40] = true
    ary[42] = true
    slice = ary.to_slice

    slice.size.should eq(6)
    slice[0].should eq(0b00001011_u8)
    slice[1].should eq(0b00000000_u8)
    slice[2].should eq(0b11010000_u8)
    slice[3].should eq(0b00000000_u8)
    slice[4].should eq(0b00000000_u8)
    slice[5].should eq(0b00000101_u8)
  end

  it "read bits written from slice" do
    ary = BitArray.new(43) # 5 bytes 3 bits
    slice = ary.to_slice
    slice[0] = 0b10101010_u8
    slice[1] = 0b01010101_u8
    slice[5] = 0b11111101_u8
    ary.each_with_index do |e, i|
      e.should eq({1, 3, 5, 7, 8, 10, 12, 14, 40, 42}.includes?(i))
    end
  end

  it "provides an iterator" do
    ary = BitArray.new(2)
    ary[0] = true
    ary[1] = false

    iter = ary.each
    iter.next.should be_true
    iter.next.should be_false
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should be_true

    iter.rewind
    iter.cycle.first(3).to_a.should eq([true, false, true])
  end

  it "provides an index iterator" do
    ary = BitArray.new(2)

    iter = ary.each_index
    iter.next.should eq(0)
    iter.next.should eq(1)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(0)
  end

  it "provides a reverse iterator" do
    ary = BitArray.new(2)
    ary[0] = true
    ary[1] = false

    iter = ary.reverse_each
    iter.next.should be_false
    iter.next.should be_true
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should be_false
  end
end
