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

  it "does hexdump" do
    ascii_table = <<-EOF
      2021 2223 2425 2627 2829 2a2b 2c2d 2e2f   !"#$%&'()*+,-./
      3031 3233 3435 3637 3839 3a3b 3c3d 3e3f  0123456789:;<=>?
      4041 4243 4445 4647 4849 4a4b 4c4d 4e4f  @ABCDEFGHIJKLMNO
      5051 5253 5455 5657 5859 5a5b 5c5d 5e5f  PQRSTUVWXYZ[\\]^_
      6061 6263 6465 6667 6869 6a6b 6c6d 6e6f  `abcdefghijklmno
      7071 7273 7475 7677 7879 7a7b 7c7d 7e7f  pqrstuvwxyz{|}~.
      EOF

    slice = StaticArray(UInt8, 96).new(&.to_u8.+(32)).to_slice
    slice.hexdump.should eq(ascii_table)

    ascii_table_plus = <<-EOF
      2021 2223 2425 2627 2829 2a2b 2c2d 2e2f   !"#$%&'()*+,-./
      3031 3233 3435 3637 3839 3a3b 3c3d 3e3f  0123456789:;<=>?
      4041 4243 4445 4647 4849 4a4b 4c4d 4e4f  @ABCDEFGHIJKLMNO
      5051 5253 5455 5657 5859 5a5b 5c5d 5e5f  PQRSTUVWXYZ[\\]^_
      6061 6263 6465 6667 6869 6a6b 6c6d 6e6f  `abcdefghijklmno
      7071 7273 7475 7677 7879 7a7b 7c7d 7e7f  pqrstuvwxyz{|}~.
      8081 8283 84                             .....
      EOF

    plus = StaticArray(UInt8, 101).new(&.to_u8.+(32)).to_slice
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

  it "uses percent vars in [] macro (#2954)" do
    slices = itself(Slice[1, 2], Slice[3])
    slices[0].to_a.should eq([1, 2])
    slices[1].to_a.should eq([3])
  end
end

private def itself(*args)
  args
end
