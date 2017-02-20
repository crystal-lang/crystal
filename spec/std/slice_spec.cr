require "spec"

describe "Slice" do
  it "gets pointer and size" do
    pointer = Pointer.malloc(1, 0)
    slice = Slice.new(pointer, 1)
    slice.pointer(0).should eq(pointer)
    slice.size.should eq(1)
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
    slice = Slice.new(3) { |i| i + 1 }

    slice1 = slice + 1
    slice1.size.should eq(2)
    slice1[0].should eq(2)
    slice1[1].should eq(3)

    slice3 = slice + 3
    slice3.size.should eq(0)

    expect_raises(IndexError) { slice + 4 }
    expect_raises(IndexError) { slice + (-1) }
  end

  it "does [] with start and count" do
    slice = Slice.new(4) { |i| i + 1 }
    slice1 = slice[1, 2]
    slice1.size.should eq(2)
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

  it "raises if size is negative on new" do
    expect_raises(ArgumentError) { Slice.new(-1, 0) }
  end

  it "does to_s" do
    slice = Slice.new(4) { |i| i + 1 }
    slice.to_s.should eq("Slice[1, 2, 3, 4]")
  end

  it "does to_s for bytes" do
    slice = Bytes[1, 2, 3]
    slice.to_s.should eq("Bytes[1, 2, 3]")
  end

  it "gets pointer" do
    slice = Slice.new(4, 0)
    expect_raises(IndexError) { slice.pointer(5) }
    expect_raises(IndexError) { slice.pointer(-1) }
  end

  it "does copy_from pointer" do
    pointer = Pointer.malloc(4) { |i| i + 1 }
    slice = Slice.new(4, 0)
    slice.copy_from(pointer, 4)
    4.times { |i| slice[i].should eq(i + 1) }

    expect_raises(IndexError) { slice.copy_from(pointer, 5) }
  end

  it "does copy_to pointer" do
    pointer = Pointer.malloc(4, 0)
    slice = Slice.new(4) { |i| i + 1 }
    slice.copy_to(pointer, 4)
    4.times { |i| pointer[i].should eq(i + 1) }

    expect_raises(IndexError) { slice.copy_to(pointer, 5) }
  end

  describe ".copy_to(Slice)" do
    it "copies bytes" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(4) { 'b' }

      src.copy_to(dst)
      dst.should eq(src)
    end

    it "raises if dst is smaller" do
      src = Slice.new(8) { 'a' }
      dst = Slice.new(4) { 'b' }

      expect_raises(IndexError) { src.copy_to(dst) }
    end

    it "copies at most src.size" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(8) { 'b' }

      src.copy_to(dst)
      dst.should eq(Slice['a', 'a', 'a', 'a', 'b', 'b', 'b', 'b'])
    end
  end

  describe ".copy_from(Slice)" do
    it "copies bytes" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(4) { 'b' }

      dst.copy_from(src)
      dst.should eq(src)
    end

    it "raises if dst is smaller" do
      src = Slice.new(8) { 'a' }
      dst = Slice.new(4) { 'b' }

      expect_raises(IndexError) { dst.copy_from(src) }
    end

    it "copies at most src.size" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(8) { 'b' }

      dst.copy_from(src)
      dst.should eq(Slice['a', 'a', 'a', 'a', 'b', 'b', 'b', 'b'])
    end
  end

  describe ".move_to(Slice)" do
    it "moves bytes" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(4) { 'b' }

      src.move_to(dst)
      dst.should eq(src)
    end

    it "raises if dst is smaller" do
      src = Slice.new(8) { 'a' }
      dst = Slice.new(4) { 'b' }

      expect_raises(IndexError) { src.move_to(dst) }
    end

    it "moves most src.size" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(8) { 'b' }

      src.move_to(dst)
      dst.should eq(Slice['a', 'a', 'a', 'a', 'b', 'b', 'b', 'b'])
    end

    it "handles intersecting ranges" do
      # Test with ranges offset by 0 to 8 bytes
      (0..8).each do |offset|
        buf = Slice.new(16) { |i| 'a' + i }
        dst = buf[0, 8]
        src = buf[offset, 8]

        src.move_to(dst)

        result = (0..7).map { |i| 'a' + i + offset }
        dst.should eq(Slice.new(result.to_unsafe, result.size))
      end
    end
  end

  describe ".move_from(Slice)" do
    it "moves bytes" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(4) { 'b' }

      dst.move_from(src)
      dst.should eq(src)
    end

    it "raises if dst is smaller" do
      src = Slice.new(8) { 'a' }
      dst = Slice.new(4) { 'b' }

      expect_raises(IndexError) { dst.move_from(src) }
    end

    it "moves at most src.size" do
      src = Slice.new(4) { 'a' }
      dst = Slice.new(8) { 'b' }

      dst.move_from(src)
      dst.should eq(Slice['a', 'a', 'a', 'a', 'b', 'b', 'b', 'b'])
    end

    it "handles intersecting ranges" do
      # Test with ranges offset by 0 to 8 bytes
      (0..8).each do |offset|
        buf = Slice.new(16) { |i| 'a' + i }
        dst = buf[0, 8]
        src = buf[offset, 8]

        dst.move_from(src)

        result = (0..7).map { |i| 'a' + i + offset }
        dst.should eq(Slice.new(result.to_unsafe, result.size))
      end
    end
  end

  it "does hexstring" do
    slice = Bytes.new(4) { |i| i.to_u8 + 1 }
    slice.hexstring.should eq("01020304")
  end

  it "does hexdump for empty slice" do
    Bytes.empty.hexdump.should eq("")
  end

  it "does hexdump" do
    ascii_table = <<-EOF
      00000000  20 21 22 23 24 25 26 27  28 29 2a 2b 2c 2d 2e 2f   !"#$%&'()*+,-./
      00000010  30 31 32 33 34 35 36 37  38 39 3a 3b 3c 3d 3e 3f  0123456789:;<=>?
      00000020  40 41 42 43 44 45 46 47  48 49 4a 4b 4c 4d 4e 4f  @ABCDEFGHIJKLMNO
      00000030  50 51 52 53 54 55 56 57  58 59 5a 5b 5c 5d 5e 5f  PQRSTUVWXYZ[\\]^_
      00000040  60 61 62 63 64 65 66 67  68 69 6a 6b 6c 6d 6e 6f  `abcdefghijklmno
      00000050  70 71 72 73 74 75 76 77  78 79 7a 7b 7c 7d 7e 7f  pqrstuvwxyz{|}~.
      EOF

    slice = Bytes.new(96) { |i| i.to_u8 + 32 }
    slice.hexdump.should eq(ascii_table)

    ascii_table_plus = <<-EOF
      00000000  20 21 22 23 24 25 26 27  28 29 2a 2b 2c 2d 2e 2f   !"#$%&'()*+,-./
      00000010  30 31 32 33 34 35 36 37  38 39 3a 3b 3c 3d 3e 3f  0123456789:;<=>?
      00000020  40 41 42 43 44 45 46 47  48 49 4a 4b 4c 4d 4e 4f  @ABCDEFGHIJKLMNO
      00000030  50 51 52 53 54 55 56 57  58 59 5a 5b 5c 5d 5e 5f  PQRSTUVWXYZ[\\]^_
      00000040  60 61 62 63 64 65 66 67  68 69 6a 6b 6c 6d 6e 6f  `abcdefghijklmno
      00000050  70 71 72 73 74 75 76 77  78 79 7a 7b 7c 7d 7e 7f  pqrstuvwxyz{|}~.
      00000060  80 81 82 83 84                                    .....
      EOF

    plus = Bytes.new(101) { |i| i.to_u8 + 32 }
    plus.hexdump.should eq(ascii_table_plus)
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

    iter.rewind
    iter.cycle.first(5).to_a.should eq([1, 2, 3, 1, 2])
  end

  it "does reverse iterator" do
    slice = Slice(Int32).new(3) { |i| i + 1 }
    iter = slice.reverse_each
    iter.next.should eq(3)
    iter.next.should eq(2)
    iter.next.should eq(1)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(3)
  end

  it "does index iterator" do
    slice = Slice(Int32).new(2) { |i| i + 1 }
    iter = slice.each_index
    iter.next.should eq(0)
    iter.next.should eq(1)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(0)
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

  it "does bytesize" do
    slice = Slice(Int32).new(2)
    slice.bytesize.should eq(8)
  end

  it "does ==" do
    a = Slice.new(3) { |i| i }
    b = Slice.new(3) { |i| i }
    c = Slice.new(3) { |i| i + 1 }
    a.should eq(b)
    a.should_not eq(c)
  end

  it "does macro []" do
    slice = Slice[1, 'a', "foo"]
    slice.should be_a(Slice(Int32 | Char | String))
    slice.size.should eq(3)
    slice[0].should eq(1)
    slice[1].should eq('a')
    slice[2].should eq("foo")
  end

  it "does macro [] with numbers (#3055)" do
    slice = Bytes[1, 2, 3]
    slice.should be_a(Bytes)
    slice.to_a.should eq([1, 2, 3])
  end

  it "uses percent vars in [] macro (#2954)" do
    slices = itself(Slice[1, 2], Slice[3])
    slices[0].to_a.should eq([1, 2])
    slices[1].to_a.should eq([3])
  end

  it "reverses" do
    slice = Bytes[1, 2, 3]
    slice.reverse!
    slice.to_a.should eq([3, 2, 1])
  end

  it "shuffles" do
    a = Bytes[1, 2, 3]
    a.shuffle!
    b = [1, 2, 3]
    3.times { a.includes?(b.shift).should be_true }
  end

  it "creates empty slice" do
    slice = Slice(Int32).empty
    slice.empty?.should be_true
  end

  it "creates read-only slice" do
    slice = Slice.new(3, 0, read_only: true)
    expect_raises { slice[0] = 1 }
    expect_raises { slice.copy_from(slice) }

    subslice = slice[0, 1]
    expect_raises { subslice[0] = 1 }

    slice = Bytes[1, 2, 3, read_only: true]
    expect_raises { slice[0] = 0_u8 }
  end
end

private def itself(*args)
  args
end
