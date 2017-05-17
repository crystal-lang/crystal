require "spec"
require "bit_array"

private def from_int(size : Int32, int : Int)
  ba = BitArray.new(size)
  (0).upto(size - 1) { |i| ba[i] = int.bit(size - i - 1) > 0 }
  ba
end

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

  describe "==" do
    it "compares empty" do
      (BitArray.new(0)).should eq(BitArray.new(0))
      from_int(1, 0b1).should_not eq(BitArray.new(0))
      (BitArray.new(0)).should_not eq(from_int(1, 0b1))
    end

    it "compares elements" do
      from_int(3, 0b101).should eq(from_int(3, 0b101))
      from_int(3, 0b101).should_not eq(from_int(3, 0b010))
    end

    it "compares other" do
      a = from_int(3, 0b101)
      b = from_int(3, 0b101)
      c = from_int(4, 0b1111)
      d = from_int(3, 0b010)
      (a == b).should be_true
      (b == c).should be_false
      (a == d).should be_false
    end
  end

  describe "[]" do
    it "gets on inclusive range" do
      from_int(6, 0b011110)[1..4].should eq(from_int(4, 0b1111))
    end

    it "gets on inclusive range with negative indices" do
      from_int(6, 0b011110)[-5..-2].should eq(from_int(4, 0b1111))
    end

    it "gets on exclusive range" do
      from_int(6, 0b010100)[1...4].should eq(from_int(3, 0b101))
    end

    it "gets on exclusive range with negative indices" do
      from_int(6, 0b010100)[-5...-2].should eq(from_int(3, 0b101))
    end

    it "gets on range with start higher than end" do
      from_int(3, 0b101)[2..1].should eq(BitArray.new(0))
      from_int(3, 0b101)[3..1].should eq(BitArray.new(0))
      expect_raises IndexError do
        from_int(3, 0b101)[4..1]
      end
    end

    it "gets on range with start higher than negative end" do
      from_int(3, 0b011)[1..-1].should eq(from_int(2, 0b11))
      from_int(3, 0b011)[2..-2].should eq(BitArray.new(0))
    end

    it "raises on index out of bounds with range" do
      expect_raises IndexError do
        from_int(3, 0b111)[4..6]
      end
    end

    it "gets with start and count" do
      from_int(6, 0b011100)[1, 3].should eq(from_int(3, 0b111))
    end

    it "gets with start and count exceeding size" do
      from_int(3, 0b011)[1, 3].should eq(from_int(2, 0b11))
    end

    it "gets with negative start" do
      from_int(6, 0b001100)[-4, 2].should eq(from_int(2, 0b11))
    end

    it "raises on index out of bounds with start and count" do
      expect_raises IndexError do
        from_int(3, 0b101)[4, 0]
      end
    end

    it "raises on negative count" do
      expect_raises ArgumentError do
        from_int(3, 0b101)[3, -1]
      end
    end

    it "raises on index out of bounds" do
      expect_raises IndexError do
        from_int(3, 0b101)[-4, 2]
      end
    end

    it "raises on negative count" do
      expect_raises ArgumentError, /Negative count: -1/ do
        from_int(3, 0b101)[1, -1]
      end
    end

    it "raises on negative count on empty Array" do
      ba = BitArray.new(0)
      expect_raises ArgumentError, /Negative count: -1/ do
        ba[0, -1]
      end
    end

    it "gets 0, 0 on empty array" do
      a = BitArray.new(0)
      a[0, 0].should eq(a)
    end

    it "gets (0..0) on empty array" do
      a = BitArray.new(0)
      a[0..0].should eq(a)
    end

    it "doesn't exceed limits" do
      from_int(1, 0b1)[0..3].should eq(from_int(1, 0b1))
    end

    it "returns empty if at end" do
      from_int(1, 0b1)[1, 0].should eq(BitArray.new(0))
      from_int(1, 0b1)[1, 10].should eq(BitArray.new(0))
    end

    it "raises on too negative left bound" do
      expect_raises IndexError do
        from_int(3, 0b101)[-4..0]
      end
    end

    it "gets on medium bitarrays" do
      ba = BitArray.new(40)
      ba[30] = true
      ba[31] = true
      ba[32] = true
      ba[34] = true
      ba[37] = true

      ba[28..-1].should eq(from_int(12, 0b001110100100))
    end

    it "gets on large bitarrays" do
      ba = BitArray.new(100)
      ba[30] = true
      ba[31] = true
      ba[32] = true
      ba[34] = true
      ba[37] = true

      ba[28..40].should eq(from_int(13, 0b0011101001000))

      ba[62] = true
      ba[63] = true
      ba[64] = true
      ba[66] = true
      ba[69] = true

      ba[60..72].should eq(from_int(13, 0b0011101001000))
      ba[28..72].should eq(from_int(45, 0b001110100100000000000000000000000011101001000_u64))
    end

    it "preserves equality" do
      ba = BitArray.new(100)
      25.upto(42) { |i| ba[i] = true }

      ba[28..40].should eq(from_int(13, 0b1111111111111))
    end
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
