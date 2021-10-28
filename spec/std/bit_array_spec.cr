require "spec"
require "bit_array"
require "spec/helpers/iterate"

private def from_int(size : Int32, int : Int)
  ba = BitArray.new(size)
  (0).upto(size - 1) { |i| ba[i] = int.bit(size - i - 1) > 0 }
  ba
end

private def assert_no_unused_bits(ba : BitArray, *, file = __FILE__, line = __LINE__)
  bit_count = 32 * ((ba.size - 1) // 32 + 1)
  (ba.size...bit_count).each do |index|
    ba.unsafe_fetch(index).should be_false, file: file, line: line
  end
end

private def assert_rotates!(from : BitArray, n : Int, to : BitArray, *, file = __FILE__, line = __LINE__)
  from.rotate!(n).should eq(from), file: file, line: line
  from.should eq(to), file: file, line: line
  assert_no_unused_bits from, file: file, line: line
end

private def assert_rotates!(from : BitArray, to : BitArray, *, file = __FILE__, line = __LINE__)
  from.rotate!.should eq(from), file: file, line: line
  from.should eq(to), file: file, line: line
  assert_no_unused_bits from, file: file, line: line
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

      e = from_int(16, 0b01001101_00011111)
      f = from_int(16, 0b00000000_00011111)
      (e == f).should be_false
    end

    it "compares other initialized with true (#8543)" do
      a = BitArray.new(26, true)
      b = BitArray.new(26, true)
      b[23] = false
      (a == b).should be_false
    end

    it "compares other type" do
      from_int(3, 0b101).should_not eq("other type")
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

    it "gets on endless range" do
      from_int(6, 0b011110)[2..nil].should eq(from_int(4, 0b1110))
    end

    it "gets on beginless range" do
      from_int(6, 0b011110)[nil..2].should eq(from_int(3, 0b011))
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

      ba[28..-1].should eq(from_int(12, 0b0011_10100100))
    end

    it "gets on large bitarrays" do
      ba = BitArray.new(100)
      ba[30] = true
      ba[31] = true
      ba[32] = true
      ba[34] = true
      ba[37] = true

      ba[28..40].should eq(from_int(13, 0b00111_01001000))

      ba[62] = true
      ba[63] = true
      ba[64] = true
      ba[66] = true
      ba[69] = true

      ba[60..72].should eq(from_int(13, 0b00111_01001000))
      ba[28..72].should eq(from_int(45, 0b00111_01001000_00000000_00000000_00000111_01001000_u64))
    end

    it "preserves equality" do
      ba = BitArray.new(100)
      25.upto(42) { |i| ba[i] = true }

      ba[28..40].should eq(from_int(13, 0b11111_11111111))
    end

    it "does not cause overflow (#8494)" do
      ba = BitArray.new(64, true)
      ba[0] = false
      ba[33] = false
      ba[0, 32].should eq(from_int(32, 0b01111111_11111111_11111111_11111111_u32))
      ba[1, 32].should eq(from_int(32, 0b11111111_11111111_11111111_11111111_u32))
      ba[2, 32].should eq(from_int(32, 0b11111111_11111111_11111111_11111110_u32))
    end

    it "zeroes unused bits" do
      ba = BitArray.new(32, true)
      assert_no_unused_bits ba[0, 26]
      assert_no_unused_bits ba[7, 11]

      ba = BitArray.new(64, true)
      assert_no_unused_bits ba[0, 26]
      assert_no_unused_bits ba[0, 33]
      assert_no_unused_bits ba[7, 53]

      ba = BitArray.new(100, true)
      assert_no_unused_bits ba[60, 26]
      assert_no_unused_bits ba[0, 97]

      ba = BitArray.new(38, true)
      ba[0, 34].should eq(BitArray.new(34, true))
    end
  end

  describe "#toggle" do
    it "toggles a bit" do
      ary = BitArray.new(32)
      ary[3].should be_false

      ary.toggle(3)
      ary[3].should be_true

      ary.toggle(3)
      ary[3].should be_false
    end

    it "toggles with index and count" do
      ary = from_int(4, 0b0011)
      ary.toggle(1, 2)
      ary.should eq(from_int(4, 0b0101))

      ary = from_int(40, 0b00110011_01010101)
      ary.toggle(30, 6)
      ary[24..].should eq(from_int(16, 0b00110000_10100101))

      ary = from_int(32, 0b10000000_00000000_00000000_00000001)
      ary.toggle(0, 32)
      ary.should eq(from_int(32, 0b01111111_11111111_11111111_11111110))
    end

    it "toggles with index and count, not enough bits" do
      ary = from_int(4, 0b0011)
      ary.toggle(1, 5)
      ary.should eq(from_int(4, 0b0100))
      (4..31).each { |i| ary.unsafe_fetch(i).should be_false }

      ary = from_int(40, 0b00110011_01010101)
      ary.toggle(30, 12)
      ary[24..].should eq(from_int(16, 0b00110000_10101010))
      (40..63).each { |i| ary.unsafe_fetch(i).should be_false }
    end

    it "toggles with index == size and count" do
      ary = from_int(4, 0b0011)
      ary.toggle(4, 2)
      ary.should eq(from_int(4, 0b0011))
      (4..31).each { |i| ary.unsafe_fetch(i).should be_false }

      ary = from_int(40, 0b00110011_01010101)
      ary.toggle(40, 6)
      ary[24..].should eq(from_int(16, 0b00110011_01010101))
      (40..63).each { |i| ary.unsafe_fetch(i).should be_false }
    end

    it "toggles with index < 0 and count" do
      ary = from_int(4, 0b0011)
      ary.toggle(-3, 2)
      ary.should eq(from_int(4, 0b0101))

      ary = from_int(40, 0b00110011_01010101)
      ary.toggle(-10, 6)
      ary[24..].should eq(from_int(16, 0b00110000_10100101))
    end

    it "raises on out of bound index" do
      expect_raises(IndexError) { BitArray.new(2).toggle(2) }
      expect_raises(IndexError) { BitArray.new(2).toggle(-3) }

      expect_raises(IndexError) { BitArray.new(2).toggle(3, 1) }
      expect_raises(IndexError) { BitArray.new(2).toggle(-3, 1) }
    end

    it "raises on negative count" do
      expect_raises(ArgumentError) { BitArray.new(2).toggle(0, -1) }
    end

    it "toggles with range" do
      ary = from_int(40, 0b00110011_01010101)
      ary.toggle(30..35)
      ary[24..].should eq(from_int(16, 0b00110000_10100101))
    end

    it "toggles zero bits correctly" do
      ary = BitArray.new(32)
      ary.toggle(0, 0)
      ary.none?.should be_true
      ary.toggle(32, 0)
      ary.none?.should be_true
      ary.toggle(32, 2)
      ary.none?.should be_true
    end
  end

  it "inverts all bits" do
    ary = BitArray.new(100)
    ary.none?.should be_true

    ary.invert
    ary.all?.should be_true
    assert_no_unused_bits ary

    ary[50] = false
    ary[33] = false
    ary.count { |b| b }.should eq(98)

    ary.invert
    ary.count { |b| b }.should eq(2)
  end

  describe "#rotate!" do
    it "rotates empty BitArray" do
      assert_rotates! from_int(0, 0), from_int(0, 0)
      assert_rotates! from_int(0, 0), 0, from_int(0, 0)
      assert_rotates! from_int(0, 0), 1, from_int(0, 0)
      assert_rotates! from_int(0, 0), -1, from_int(0, 0)
    end

    it "rotates short BitArray" do
      assert_rotates! from_int(5, 0b10011), from_int(5, 0b00111)
      assert_rotates! from_int(5, 0b10011), 0, from_int(5, 0b10011)
      assert_rotates! from_int(5, 0b10011), 1, from_int(5, 0b00111)
      assert_rotates! from_int(5, 0b10011), 2, from_int(5, 0b01110)
      assert_rotates! from_int(5, 0b10011), 3, from_int(5, 0b11100)
      assert_rotates! from_int(5, 0b10011), 4, from_int(5, 0b11001)
      assert_rotates! from_int(5, 0b10011), 5, from_int(5, 0b10011)
      assert_rotates! from_int(5, 0b10011), 6, from_int(5, 0b00111)
      assert_rotates! from_int(5, 0b10011), -1, from_int(5, 0b11001)
      assert_rotates! from_int(5, 0b10011), -2, from_int(5, 0b11100)
      assert_rotates! from_int(5, 0b10011), -3, from_int(5, 0b01110)
      assert_rotates! from_int(5, 0b10011), -4, from_int(5, 0b00111)

      ba = from_int(5, 0b10011)
      assert_rotates! ba, from_int(5, 0b00111)
      assert_rotates! ba, from_int(5, 0b01110)
      assert_rotates! ba, 2, from_int(5, 0b11001)

      ba = from_int(32, 0b11000101_00011111_11000001_00011101_u32)
      assert_rotates! ba, 5, from_int(32, 0b10100011_11111000_00100011_10111000_u32)
      assert_rotates! ba, -8, from_int(32, 0b10111000_10100011_11111000_00100011_u32)
      assert_rotates! ba, 45, from_int(32, 0b01111111_00000100_01110111_00010100_u32)
    end

    it "rotates medium BitArray" do
      ba = from_int(64, 0b11001100_00101001_01111010_10110001_10111111_00100101_11101100_10101010_u64)
      assert_rotates! ba, from_int(64, 0b10011000_01010010_11110101_01100011_01111110_01001011_11011001_01010101_u64)
      assert_rotates! ba, 10, from_int(64, 0b01001011_11010101_10001101_11111001_00101111_01100101_01010110_01100001_u64)
      assert_rotates! ba, 51, from_int(64, 0b10110011_00001010_01011110_10101100_01101111_11001001_01111011_00101010_u64)
      assert_rotates! ba, -40, from_int(64, 0b10101100_01101111_11001001_01111011_00101010_10110011_00001010_01011110_u64)
      assert_rotates! ba, 128, from_int(64, 0b10101100_01101111_11001001_01111011_00101010_10110011_00001010_01011110_u64)
      assert_rotates! ba, 97, from_int(64, 0b01010101_01100110_00010100_10111101_01011000_11011111_10010010_11110110_u64)
    end

    it "rotates large BitArray" do
      ba = BitArray.new(200)
      ba[0] = ba[2] = ba[5] = ba[11] = ba[64] = ba[103] = ba[193] = ba[194] = true

      ba.rotate!
      ba2 = BitArray.new(200)
      ba2[199] = ba2[1] = ba2[4] = ba2[10] = ba2[63] = ba2[102] = ba2[192] = ba2[193] = true
      ba.should eq(ba2)
      assert_no_unused_bits ba

      ba.rotate!(21)
      ba2 = BitArray.new(200)
      ba2[178] = ba2[180] = ba2[183] = ba2[189] = ba2[42] = ba2[81] = ba2[171] = ba2[172] = true
      ba.should eq(ba2)
      assert_no_unused_bits ba

      ba.rotate!(192)
      ba2 = BitArray.new(200)
      ba2[186] = ba2[188] = ba2[191] = ba2[197] = ba2[50] = ba2[89] = ba2[179] = ba2[180] = true
      ba.should eq(ba2)
      assert_no_unused_bits ba

      ba.rotate!(50)
      ba2 = BitArray.new(200)
      ba2[136] = ba2[138] = ba2[141] = ba2[147] = ba2[0] = ba2[39] = ba2[129] = ba2[130] = true
      ba.should eq(ba2)
      assert_no_unused_bits ba

      ba.rotate!(123)
      ba2 = BitArray.new(200)
      ba2[13] = ba2[15] = ba2[18] = ba2[24] = ba2[77] = ba2[116] = ba2[6] = ba2[7] = true
      ba.should eq(ba2)
      assert_no_unused_bits ba
    end
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

  it "initializes with unused bits cleared" do
    ary = BitArray.new(3, true)
    assert_no_unused_bits ary
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
    slice[5] = 0b00000101_u8
    ary.each_with_index do |e, i|
      e.should eq(i.in?(1, 3, 5, 7, 8, 10, 12, 14, 40, 42))
    end
  end

  ary = BitArray.new(2)
  ary[0] = true
  ary[1] = false

  it_iterates "#each", [true, false], ary.each
  it_iterates "#each_index", [0, 1], ary.each_index
  it_iterates "#reverse_each", [false, true], ary.reverse_each

  it "provides dup" do
    a = BitArray.new(2)
    b = a.dup

    b[0] = true
    a[0].should be_false
    b[0].should be_true
  end
end
