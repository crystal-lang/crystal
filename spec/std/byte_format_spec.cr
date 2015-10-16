require "spec"

private def assert_bytes(io, *bytes)
  io.rewind
  bytes.each do |byte|
    io.read_byte.should eq(byte)
  end
  io.read_byte.should be_nil
end

private def assert_bytes_reversed(io, *bytes)
  assert_bytes io, *bytes.reverse
end

describe ByteFormat do
  describe "little endian" do
    it "writes int8" do
      io = StringIO.new
      io.write_bytes 0x12_i8, ByteFormat::LittleEndian
      assert_bytes io, 0x12
    end

    it "writes int16" do
      io = StringIO.new
      io.write_bytes 0x1234_i16, ByteFormat::LittleEndian
      assert_bytes io, 0x34, 0x12
    end

    it "writes uint16" do
      io = StringIO.new
      io.write_bytes 0x1234_u16, ByteFormat::LittleEndian
      assert_bytes io, 0x34, 0x12
    end

    it "writes int32" do
      io = StringIO.new
      io.write_bytes 0x12345678_i32, ByteFormat::LittleEndian
      assert_bytes io, 0x78, 0x56, 0x34, 0x12
    end

    it "writes int64" do
      io = StringIO.new
      io.write_bytes 0x123456789ABCDEF0_i64, ByteFormat::LittleEndian
      assert_bytes io, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
    end

    it "writes float32" do
      io = StringIO.new
      io.write_bytes 1.234_f32, ByteFormat::LittleEndian
      assert_bytes io, 0xB6, 0xF3, 0x9D, 0x3F
    end

    it "writes float64" do
      io = StringIO.new
      io.write_bytes 1.234, ByteFormat::LittleEndian
      assert_bytes io, 0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F
    end
  end

  describe "big endian" do
    it "writes int8" do
      io = StringIO.new
      io.write_bytes 0x12_i8, ByteFormat::BigEndian
      assert_bytes io, 0x12
    end

    it "writes int16" do
      io = StringIO.new
      io.write_bytes 0x1234_i16, ByteFormat::BigEndian
      assert_bytes_reversed io, 0x34, 0x12
    end

    it "writes int32" do
      io = StringIO.new
      io.write_bytes 0x12345678_i32, ByteFormat::BigEndian
      assert_bytes_reversed io, 0x78, 0x56, 0x34, 0x12
    end

    it "writes int64" do
      io = StringIO.new
      io.write_bytes 0x123456789ABCDEF0_i64, ByteFormat::BigEndian
      assert_bytes_reversed io, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
    end

    it "writes float32" do
      io = StringIO.new
      io.write_bytes 1.234_f32, ByteFormat::BigEndian
      assert_bytes_reversed io, 0xB6, 0xF3, 0x9D, 0x3F
    end

    it "writes float64" do
      io = StringIO.new
      io.write_bytes 1.234, ByteFormat::BigEndian
      assert_bytes_reversed io, 0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F
    end
  end
end
