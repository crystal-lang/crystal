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

private def new_string_io(*bytes)
  io = IO::Memory.new
  bytes.each { |byte| io.write_byte byte.to_u8 }
  io.rewind
  io
end

private module ReadBytesConverter
  def self.from_io(io : IO, format = IO::ByteFormat::NetworkEndian) : Int32
    io.read_bytes(Int32, format: format)
  end
end

describe IO::ByteFormat do
  describe "little endian" do
    describe "encode" do
      describe "to io" do
        it "writes int8" do
          io = IO::Memory.new
          io.write_bytes 0x12_i8, IO::ByteFormat::LittleEndian
          assert_bytes io, 0x12
        end

        it "writes int16" do
          io = IO::Memory.new
          io.write_bytes 0x1234_i16, IO::ByteFormat::LittleEndian
          assert_bytes io, 0x34, 0x12
        end

        it "writes uint16" do
          io = IO::Memory.new
          io.write_bytes 0x1234_u16, IO::ByteFormat::LittleEndian
          assert_bytes io, 0x34, 0x12
        end

        it "writes int32" do
          io = IO::Memory.new
          io.write_bytes 0x12345678_i32, IO::ByteFormat::LittleEndian
          assert_bytes io, 0x78, 0x56, 0x34, 0x12
        end

        it "writes int64" do
          io = IO::Memory.new
          io.write_bytes 0x123456789ABCDEF0_i64, IO::ByteFormat::LittleEndian
          assert_bytes io, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
        end

        it "writes float32" do
          io = IO::Memory.new
          io.write_bytes 1.234_f32, IO::ByteFormat::LittleEndian
          assert_bytes io, 0xB6, 0xF3, 0x9D, 0x3F
        end

        it "writes float64" do
          io = IO::Memory.new
          io.write_bytes 1.234, IO::ByteFormat::LittleEndian
          assert_bytes io, 0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F
        end
      end

      describe "to slice" do
        it "writes int8" do
          bytes = Bytes[0]
          IO::ByteFormat::LittleEndian.encode(0x12_i8, bytes)
          bytes.should eq(Bytes[0x12_i8])
        end

        it "writes int16" do
          bytes = Bytes[0, 0]
          IO::ByteFormat::LittleEndian.encode(0x1234_i16, bytes)
          bytes.should eq(Bytes[0x34, 0x12])
        end

        it "writes int16 to larger slice" do
          bytes = Bytes[0, 0, 0, 0]
          IO::ByteFormat::LittleEndian.encode(0x1234_i16, bytes)
          bytes.should eq(Bytes[0x34, 0x12, 0, 0])
        end
      end
    end

    describe "decode" do
      describe "from io" do
        it "reads int8" do
          io = new_string_io(0x12)
          int = io.read_bytes Int8, IO::ByteFormat::LittleEndian
          int.should eq(0x12_i8)
        end

        it "reads int16" do
          io = new_string_io(0x34, 0x12)
          int = io.read_bytes Int16, IO::ByteFormat::LittleEndian
          int.should eq(0x1234_i16)
        end

        it "reads unt16" do
          io = new_string_io(0x34, 0x12)
          int = io.read_bytes UInt16, IO::ByteFormat::LittleEndian
          int.should eq(0x1234_u16)
        end

        it "reads int32" do
          io = new_string_io(0x78, 0x56, 0x34, 0x12)
          int = io.read_bytes Int32, IO::ByteFormat::LittleEndian
          int.should eq(0x12345678_i32)
        end

        it "reads int64" do
          io = new_string_io(0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12)
          int = io.read_bytes Int64, IO::ByteFormat::LittleEndian
          int.should eq(0x123456789ABCDEF0_i64)
        end

        it "reads float32" do
          io = new_string_io(0xB6, 0xF3, 0x9D, 0x3F)
          float = io.read_bytes Float32, IO::ByteFormat::LittleEndian
          float.should be_close(1.234, 0.0001)
        end

        it "reads float64" do
          io = new_string_io(0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F)
          float = io.read_bytes Float64, IO::ByteFormat::LittleEndian
          float.should be_close(1.234, 0.0001)
        end

        it "reads with converter" do
          io = new_string_io(0x78, 0x56, 0x34, 0x12)
          io.read_bytes(ReadBytesConverter, IO::ByteFormat::LittleEndian).should eq 0x12345678_i32
        end
      end

      describe "from slice" do
        it "reads int8" do
          bytes = Bytes[0x12]
          int = IO::ByteFormat::LittleEndian.decode(Int8, bytes)
          int.should eq(0x12_i8)
        end

        it "reads int16" do
          bytes = Bytes[0x34, 0x12]
          int = IO::ByteFormat::LittleEndian.decode(Int16, bytes)
          int.should eq(0x1234_i16)
        end

        it "reads int16 from larger slice" do
          bytes = Bytes[0x34, 0x12, 0, 0]
          int = IO::ByteFormat::LittleEndian.decode(Int16, bytes)
          int.should eq(0x1234_i16)
        end

        it "reads float32" do
          bytes = Bytes[0xB6, 0xF3, 0x9D, 0x3F]
          float = IO::ByteFormat::LittleEndian.decode(Float32, bytes)
          float.should be_close(1.234, 0.0001)
        end

        it "reads float64" do
          bytes = Bytes[0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F]
          float = IO::ByteFormat::LittleEndian.decode(Float64, bytes)
          float.should be_close(1.234, 0.0001)
        end
      end
    end
  end

  describe "big endian" do
    describe "encode" do
      it "writes int8" do
        io = IO::Memory.new
        io.write_bytes 0x12_i8, IO::ByteFormat::BigEndian
        assert_bytes io, 0x12
      end

      it "writes int16" do
        io = IO::Memory.new
        io.write_bytes 0x1234_i16, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0x34, 0x12
      end

      it "writes int32" do
        io = IO::Memory.new
        io.write_bytes 0x12345678_i32, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0x78, 0x56, 0x34, 0x12
      end

      it "writes int64" do
        io = IO::Memory.new
        io.write_bytes 0x123456789ABCDEF0_i64, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
      end

      it "writes float32" do
        io = IO::Memory.new
        io.write_bytes 1.234_f32, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0xB6, 0xF3, 0x9D, 0x3F
      end

      it "writes float64" do
        io = IO::Memory.new
        io.write_bytes 1.234, IO::ByteFormat::BigEndian
        assert_bytes_reversed io, 0x58, 0x39, 0xB4, 0xC8, 0x76, 0xBE, 0xF3, 0x3F
      end
    end

    describe "decode" do
      describe "from io" do
        it "reads int8" do
          io = new_string_io(0x12)
          int = io.read_bytes Int8, IO::ByteFormat::BigEndian
          int.should eq(0x12_i8)
        end

        it "reads int16" do
          io = new_string_io(0x12, 0x34)
          int = io.read_bytes Int16, IO::ByteFormat::BigEndian
          int.should eq(0x1234_i16)
        end

        it "reads unt16" do
          io = new_string_io(0x12, 0x34)
          int = io.read_bytes UInt16, IO::ByteFormat::BigEndian
          int.should eq(0x1234_u16)
        end

        it "reads int32" do
          io = new_string_io(0x12, 0x34, 0x56, 0x78)
          int = io.read_bytes Int32, IO::ByteFormat::BigEndian
          int.should eq(0x12345678_i32)
        end

        it "reads int64" do
          io = new_string_io(0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0)
          int = io.read_bytes Int64, IO::ByteFormat::BigEndian
          int.should eq(0x123456789ABCDEF0_i64)
        end

        it "reads float32" do
          io = new_string_io(0x3F, 0x9D, 0xF3, 0xB6)
          float = io.read_bytes Float32, IO::ByteFormat::BigEndian
          float.should be_close(1.234, 0.0001)
        end

        it "reads float64" do
          io = new_string_io(0x3F, 0xF3, 0xBE, 0x76, 0xC8, 0xB4, 0x39, 0x58)
          float = io.read_bytes Float64, IO::ByteFormat::BigEndian
          float.should be_close(1.234, 0.0001)
        end

        it "reads with converter" do
          io = new_string_io(0x12, 0x34, 0x56, 0x78)
          io.read_bytes(ReadBytesConverter, IO::ByteFormat::BigEndian).should eq 0x12345678_i32
        end
      end

      describe "from slice" do
        it "reads int8" do
          bytes = Bytes[0x12]
          int = IO::ByteFormat::BigEndian.decode(Int8, bytes)
          int.should eq(0x12_i8)
        end

        it "reads int16" do
          bytes = Bytes[0x12, 0x34]
          int = IO::ByteFormat::BigEndian.decode(Int16, bytes)
          int.should eq(0x1234_i16)
        end

        it "reads float32" do
          bytes = Bytes[0x3F, 0x9D, 0xF3, 0xB6]
          float = IO::ByteFormat::BigEndian.decode(Float32, bytes)
          float.should be_close(1.234, 0.0001)
        end

        it "reads float64" do
          bytes = Bytes[0x3F, 0xF3, 0xBE, 0x76, 0xC8, 0xB4, 0x39, 0x58]
          float = IO::ByteFormat::BigEndian.decode(Float64, bytes)
          float.should be_close(1.234, 0.0001)
        end
      end
    end
  end
end
