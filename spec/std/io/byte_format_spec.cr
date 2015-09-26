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

class SliceIO
  include IO

  def initialize(*bytes)
    @slice = Slice(UInt8).new(bytes.size)
    bytes.each_with_index do |byte, index|
      @slice[index] = byte.to_u8
    end
    @index = 0
  end

  def rewind
    @index = 0
  end

  def read(slice : Slice(UInt8))
    bytes_read = Math.min(slice.size, @slice.size - @index)
    return bytes_read if bytes_read == 0
    slice.copy_from((@slice + @index).pointer(@index + bytes_read), bytes_read)
    @index += 1
    bytes_read
  end

  def write(slice : Slice(UInt8))
    bytes_written = Math.min(slice.size, @slice.size - @index)
    return bytes_written if bytes_written == 0
    (@slice + @index).copy_from(slice.pointer(@index + bytes_written), bytes_written)
    @index += 1
    bytes_written
  end
end

describe IO::ByteFormat do
  describe "little endian" do
    describe "encode" do
      it "writes int8" do
        io = StringIO.new
        io.write_bytes 0x12_i8, IO::ByteFormat::LittleEndian
        assert_bytes io, 0x12
      end

      it "writes int16" do
        io = StringIO.new
        io.write_bytes 0x1234_i16, IO::ByteFormat::LittleEndian
        assert_bytes io, 0x34, 0x12
      end

      it "writes uint16" do
        io = StringIO.new
        io.write_bytes 0x1234_u16, IO::ByteFormat::LittleEndian
        assert_bytes io, 0x34, 0x12
      end

      it "writes int32" do
        io = StringIO.new
        io.write_bytes 0x12345678_i32, IO::ByteFormat::LittleEndian
        assert_bytes io, 0x78, 0x56, 0x34, 0x12
      end

      it "writes int64" do
        io = StringIO.new
        io.write_bytes 0x123456789ABCDEF0_i64, IO::ByteFormat::LittleEndian
        assert_bytes io, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
      end

      it "writes float32" do
        io = StringIO.new
        io.write_bytes 1.234_f32, IO::ByteFormat::LittleEndian
        assert_bytes io, 0xB6, 0xF3, 0x9D, 0x3F
      end

      it "writes float64" do
        io = StringIO.new
        io.write_bytes 1.234, IO::ByteFormat::LittleEndian
        assert_bytes io, 0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F
      end
    end

    describe "decode" do
      it "reads int8" do
        io = SliceIO.new(0x12)
        int = io.read_object Int8, IO::ByteFormat::LittleEndian
        int.should eq(0x12_i8)
      end

      it "reads int16" do
        io = SliceIO.new(0x34, 0x12)
        int = io.read_object Int16, IO::ByteFormat::LittleEndian
        int.should eq(0x1234_i16)
      end

      it "reads unt16" do
        io = SliceIO.new(0x34, 0x12)
        int = io.read_object UInt16, IO::ByteFormat::LittleEndian
        int.should eq(0x1234_u16)
      end

      it "reads int32" do
        io = SliceIO.new(0x78, 0x56, 0x34, 0x12)
        int = io.read_object Int32, IO::ByteFormat::LittleEndian
        int.should eq(0x12345678_i32)
      end

      it "reads int64" do
        io = SliceIO.new(0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12)
        int = io.read_object Int64, IO::ByteFormat::LittleEndian
        int.should eq(0x123456789ABCDEF0_i64)
      end

      it "reads float32" do
        io = SliceIO.new(0xB6, 0xF3, 0x9D, 0x3F)
        float = io.read_object Float32, IO::ByteFormat::LittleEndian
        float.should be_close(1.234, 0.0001)
      end

      it "reads float64" do
        io = SliceIO.new(0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F)
        float = io.read_object Float64, IO::ByteFormat::LittleEndian
        float.should be_close(1.234, 0.0001)
      end
    end
  end

  describe "big endian" do
    describe "encode" do
      it "writes int8" do
        io = StringIO.new
        io.write_bytes 0x12_i8, IO::ByteFormat::BigEndian
        assert_bytes io, 0x12
      end

      it "writes int16" do
        io = StringIO.new
        io.write_bytes 0x1234_i16, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0x34, 0x12
      end

      it "writes int32" do
        io = StringIO.new
        io.write_bytes 0x12345678_i32, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0x78, 0x56, 0x34, 0x12
      end

      it "writes int64" do
        io = StringIO.new
        io.write_bytes 0x123456789ABCDEF0_i64, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
      end

      it "writes float32" do
        io = StringIO.new
        io.write_bytes 1.234_f32, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0xB6, 0xF3, 0x9D, 0x3F
      end

      it "writes float64" do
        io = StringIO.new
        io.write_bytes 1.234, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F
      end
    end

    describe "decode" do
      it "reads int8" do
        io = SliceIO.new(0x12)
        int = io.read_object Int8, IO::ByteFormat::BigEndian
        int.should eq(0x12_i8)
      end

      it "reads int16" do
        io = SliceIO.new(0x12, 0x34)
        int = io.read_object Int16, IO::ByteFormat::BigEndian
        int.should eq(0x1234_i16)
      end

      it "reads unt16" do
        io = SliceIO.new(0x12, 0x34)
        int = io.read_object UInt16, IO::ByteFormat::BigEndian
        int.should eq(0x1234_u16)
      end

      it "reads int32" do
        io = SliceIO.new(0x12, 0x34, 0x56, 0x78)
        int = io.read_object Int32, IO::ByteFormat::BigEndian
        int.should eq(0x12345678_i32)
      end

      it "reads int64" do
        io = SliceIO.new(0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0)
        int = io.read_object Int64, IO::ByteFormat::BigEndian
        int.should eq(0x123456789ABCDEF0_i64)
      end

      it "reads float32" do
        io = SliceIO.new(0x3F, 0x9D, 0xF3, 0xB6)
        float = io.read_object Float32, IO::ByteFormat::BigEndian
        float.should be_close(1.234, 0.0001)
      end

      it "reads float64" do
        io = SliceIO.new(0x3F, 0xF3, 0xBE, 0x76, 0xC8, 0xB4, 0x39, 0x58)
        float = io.read_object Float64, IO::ByteFormat::BigEndian
        float.should be_close(1.234, 0.0001)
      end
    end
  end
end
