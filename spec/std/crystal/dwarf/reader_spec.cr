require "spec"
require "crystal/dwarf/reader"

describe Crystal::DWARF::Reader do
  it "#read_u8" do
    bytes = Bytes[0x01, 0x02]
    reader = Crystal::DWARF::Reader.new(bytes)
    reader.read_u8.should eq(0x01)
    reader.read_u8.should eq(0x02)
    expect_raises(IO::EOFError) { reader.read_u8 }
  end

  describe "#read_u16" do
    it do
      bytes = Bytes[0x01, 0x02]
      reader = Crystal::DWARF::Reader.new(bytes)
      if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        reader.read_u16.should eq(0x0201)
      else
        reader.read_u16.should eq(0x0102)
      end
    end

    it "raises when insufficient bytes" do
      bytes = Bytes[0x01]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_u16 }
    end
  end

  describe "#read_u24" do
    it do
      bytes = Bytes[0x01, 0x02, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)
      if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        reader.read_u24.should eq(0x030201)
      else
        reader.read_u24.should eq(0x010203)
      end
    end

    it "raises when insufficient bytes" do
      bytes = Bytes[0x01]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_u24 }
    end
  end

  describe "#read_u32" do
    it do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04]
      reader = Crystal::DWARF::Reader.new(bytes)
      if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        reader.read_u32.should eq(0x04030201)
      else
        reader.read_u32.should eq(0x01020304)
      end
    end

    it "raises when insufficient bytes" do
      bytes = Bytes[0x01, 0x02, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_u32 }
    end
  end

  describe "#read_u64" do
    it do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
      reader = Crystal::DWARF::Reader.new(bytes)
      if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        reader.read_u64.should eq(0x0807060504030201_u64)
      else
        reader.read_u64.should eq(0x0102030405060708_u64)
      end
    end

    it "raises when insufficient bytes" do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_u64 }
    end
  end

  {% if compare_versions(Crystal::VERSION, "1.3.0") >= 0 %}
    describe "#read_u128" do
      it do
        bytes = Bytes[
          0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
          0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        ]
        reader = Crystal::DWARF::Reader.new(bytes)
        if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
          reader.read_u128.should eq(0x100F0E0D0C0B0A090807060504030201_u128)
        else
          reader.read_u128.should eq(0x0102030405060708090A0B0C0D0E0F10_u128)
        end
      end

      it "raises when insufficient bytes" do
        bytes = Bytes[
          0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
          0x09, 0x0A, 0x0B, 0x0C, 0x0D,
        ]
        reader = Crystal::DWARF::Reader.new(bytes)
        expect_raises(IO::EOFError) { reader.read_u128 }
      end
    end
  {% end %}

  describe "#read_ulong" do
    it "reads u32" do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
      reader = Crystal::DWARF::Reader.new(bytes)
      if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        reader.read_ulong(4).should eq(0x04030201_u32)
        reader.read_ulong(4).should eq(0x08070605_u32)
      else
        reader.read_ulong(4).should eq(0x01020304_u32)
        reader.read_ulong(4).should eq(0x05060708_u32)
      end
    end

    it "reads u64" do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
      reader = Crystal::DWARF::Reader.new(bytes)
      if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
        reader.read_ulong(8).should eq(0x0807060504030201_u64)
      else
        reader.read_ulong(8).should eq(0x0102030405060708_u64)
      end
    end

    it "raises when insufficient bytes" do
      bytes = Bytes[0x01, 0x02, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_ulong(4) }

      bytes = Bytes[0x01, 0x02, 0x03, 0x04, 0x05]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_ulong(8) }
    end
  end

  describe "#read_uleb128" do
    it "reads single-byte values" do
      bytes = Bytes[0x00]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.read_uleb128.should eq(0)
      reader.pos.should eq(1)
    end

    it "reads maximum single-byte value 0x7F" do
      bytes = Bytes[0x7F]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.read_uleb128.should eq(127)
      reader.pos.should eq(1)
    end

    it "reads multi-byte values" do
      bytes = Bytes[
        0x80, 0x01,
        0xFF, 0x7F,
        0x80, 0x80, 0x01,
        0xE5, 0x8E, 0x26,
        0xFF, 0xFF, 0xFF, 0x0F,
        0xFF, 0xFF, 0xFF, 0xFF, 0x0F,
      ]
      reader = Crystal::DWARF::Reader.new(bytes)

      reader.read_uleb128.should eq(128)
      reader.pos.should eq 2

      reader.read_uleb128.should eq(16383)
      reader.pos.should eq 4

      reader.read_uleb128.should eq(16384)
      reader.pos.should eq 7

      reader.read_uleb128.should eq(624485)
      reader.pos.should eq 10

      reader.read_uleb128.should eq(33554431)
      reader.pos.should eq 14

      reader.read_uleb128.should eq(UInt32::MAX)
      reader.eof?.should be_true
    end

    it "raises IO::EOFError when insufficient bytes" do
      bytes = Bytes[0x80]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_uleb128 }
    end
  end

  describe "#read_sleb128" do
    it "reads single-byte values" do
      bytes = Bytes[0x00]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.read_sleb128.should eq(0)
      reader.pos.should eq(1)
    end

    it "reads maximum single-byte value 0x7F" do
      bytes = Bytes[0x7F]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.read_sleb128.should eq(-1)
      reader.pos.should eq(1)
    end

    it "reads multi-byte values" do
      bytes = Bytes[
        0x80, 0x01,
        0x80, 0x7F,
        0xFF, 0xFF, 0x00,
        0x81, 0x80, 0x7F,
        0x80, 0x80, 0x01,
        0x80, 0x80, 0x7F,
        0xFF, 0xFF, 0xFF, 0xFF, 0x07,
        0x80, 0x80, 0x80, 0x80, 0x78,
      ]
      reader = Crystal::DWARF::Reader.new(bytes)

      reader.read_sleb128.should eq(128)
      reader.pos.should eq 2

      reader.read_sleb128.should eq(-128)
      reader.pos.should eq 4

      reader.read_sleb128.should eq(16383)
      reader.pos.should eq 7

      reader.read_sleb128.should eq(-16383)
      reader.pos.should eq 10

      reader.read_sleb128.should eq(16384)
      reader.pos.should eq 13

      reader.read_sleb128.should eq(-16384)
      reader.pos.should eq 16

      reader.read_sleb128.should eq(Int32::MAX)
      reader.pos.should eq(21)

      reader.read_sleb128.should eq(Int32::MIN)
      reader.eof?.should be_true
    end

    it "raises IO::EOFError when insufficient bytes" do
      bytes = Bytes[0x80]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_sleb128 }
    end
  end

  describe "#read(slice)" do
    it "copies bytes into the provided slice and advances position" do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04]
      reader = Crystal::DWARF::Reader.new(bytes)
      slice = Bytes.new(2)

      reader.read(slice)
      slice.should eq(bytes[0, 2])
      reader.pos.should eq(2)

      reader.read(slice)
      slice.should eq(bytes[2, 2])
      reader.pos.should eq(4)
    end

    it "raises IO::EOFError when insufficient bytes" do
      bytes = Bytes[0x01, 0x02]
      reader = Crystal::DWARF::Reader.new(bytes)
      slice = Bytes.new(3)
      expect_raises(IO::EOFError) { reader.read(slice) }
    end
  end

  describe "#read(bytes_count)" do
    it "returns a sub-slice of the reader's bytes and advances position" do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04]
      reader = Crystal::DWARF::Reader.new(bytes)

      slice = reader.read(2)
      slice.to_unsafe.should eq(bytes.to_unsafe)
      slice.size.should eq(2)
      reader.pos.should eq(2)

      slice = reader.read(2)
      slice.to_unsafe.should eq(bytes.to_unsafe + 2)
      slice.size.should eq(2)
      reader.pos.should eq(4)
    end

    it "raises IO::EOFError when insufficient bytes" do
      bytes = Bytes[0x01, 0x02]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read(3) }
    end
  end

  describe "#skip" do
    it "advances position by the requested count" do
      bytes = Bytes[0x01, 0x02, 0x03, 0x04, 0x05]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.skip(2)
      reader.pos.should eq(2)
      reader.skip(3)
      reader.pos.should eq(5)
      expect_raises(IO::EOFError) { reader.skip(1) }
    end

    it "raises IO::EOFError when skipping beyond end" do
      bytes = Bytes[0x01, 0x02]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.skip(3) }
    end
  end

  describe "#read_string" do
    it "reads until NULL byte and returns preceding bytes" do
      bytes = Bytes[0x01, 0x02, 0x00, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)

      slice = reader.read_string
      slice.to_unsafe.should eq(bytes.to_unsafe)
      slice.size.should eq(2)
      reader.pos.should eq(3)
    end

    it "returns an empty Bytes if first byte is NULL" do
      bytes = Bytes[0x00, 0x01]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.read_string.should be_empty
      reader.pos.should eq(1)
    end

    it "raises when no NULL byte found" do
      bytes = Bytes[0x01, 0x02, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.read_string }
      reader.eof?.should be_true
    end
  end

  describe "#skip_string" do
    it "skips bytes until NULL byte and advances position" do
      bytes = Bytes[0x01, 0x02, 0x00, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)
      reader.skip_string
      reader.pos.should eq(3)
    end

    it "raises IO::EOFError when no NULL byte found" do
      bytes = Bytes[0x01, 0x02, 0x03]
      reader = Crystal::DWARF::Reader.new(bytes)
      expect_raises(IO::EOFError) { reader.skip_string }
      reader.eof?.should be_true
    end
  end
end
