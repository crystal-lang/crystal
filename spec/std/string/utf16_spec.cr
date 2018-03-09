require "spec"

describe "String UTF16" do
  describe "to_utf16" do
    it "in the range U+0000..U+D7FF" do
      encoded = "\u{0}hello\u{d7ff}".to_utf16
      encoded.should eq(Slice[0_u16, 0x68_u16, 0x65_u16, 0x6c_u16, 0x6c_u16, 0x6f_u16, 0xd7ff_u16])
    end

    it "in the range U+E000 to U+FFFF" do
      encoded = "\u{e000}\u{ffff}".to_utf16
      encoded.should eq(Slice[0xe000_u16, 0xffff_u16])
    end

    it "in the range U+10000..U+10FFFF" do
      encoded = "\u{10000}\u{10FFFF}".to_utf16
      encoded.should eq(Slice[0xd800_u16, 0xdc00_u16, 0xdbff_u16, 0xdfff_u16])
    end

    it "in the range U+D800..U+DFFF" do
      encoded = "\u{D800}\u{DFFF}".to_utf16
      encoded.should eq(Slice[0xFFFD_u16, 0xFFFD_u16])
    end
  end

  describe "from_utf16" do
    it "in the range U+0000..U+D7FF" do
      input = Slice[0_u16, 0x68_u16, 0x65_u16, 0x6c_u16, 0x6c_u16, 0x6f_u16, 0xd7ff_u16]
      String.from_utf16(input).should eq("\u{0}hello\u{d7ff}")
    end

    it "in the range U+E000 to U+FFFF" do
      input = Slice[0xe000_u16, 0xffff_u16]
      String.from_utf16(input).should eq("\u{e000}\u{ffff}")
    end

    it "in the range U+10000..U+10FFFF" do
      input = Slice[0xd800_u16, 0xdc00_u16]
      String.from_utf16(input).should eq("\u{10000}")
    end

    it "in the range U+D800..U+DFFF" do
      input = Slice[0xdc00_u16, 0xd800_u16]
      String.from_utf16(input).should eq("\u{fffd}\u{fffd}")
    end

    it "handles null bytes" do
      slice = Slice[104_u16, 105_u16, 0_u16, 55296_u16, 56485_u16]
      String.from_utf16(slice).should eq("hi\0000𐂥")
      String.from_utf16(slice.to_unsafe).should eq("hi")
    end
  end
end
