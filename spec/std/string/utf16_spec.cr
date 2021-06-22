require "spec"

describe "String UTF16" do
  describe "to_utf16" do
    it "in the range U+0000..U+FF" do
      encoded = "\u{0}hello\u{ff}".to_utf16
      encoded.should eq(Slice[0_u16, 0x68_u16, 0x65_u16, 0x6c_u16, 0x6c_u16, 0x6f_u16, 0xff_u16])
      encoded.unsafe_fetch(encoded.size).should eq 0_u16
    end

    it "in the range U+0000..U+D7FF" do
      encoded = "\u{0}hello\u{d7ff}".to_utf16
      encoded.should eq(Slice[0_u16, 0x68_u16, 0x65_u16, 0x6c_u16, 0x6c_u16, 0x6f_u16, 0xd7ff_u16])
      encoded.unsafe_fetch(encoded.size).should eq 0_u16
    end

    it "in the range U+E000 to U+FFFF" do
      encoded = "\u{e000}\u{ffff}".to_utf16
      encoded.should eq(Slice[0xe000_u16, 0xffff_u16])
      encoded.unsafe_fetch(encoded.size).should eq 0_u16
    end

    it "in the range U+10000..U+10FFFF" do
      encoded = "\u{10000}\u{10FFFF}".to_utf16
      encoded.should eq(Slice[0xd800_u16, 0xdc00_u16, 0xdbff_u16, 0xdfff_u16])
      encoded.unsafe_fetch(encoded.size).should eq 0_u16
    end

    it "in the range U+D800..U+DFFF" do
      encoded = String.new(Bytes[0xED, 0xA0, 0x80, 0xED, 0xBF, 0xBF]).to_utf16
      encoded.should eq(Slice[0xFFFD_u16, 0xFFFD_u16, 0xFFFD_u16, 0xFFFD_u16, 0xFFFD_u16, 0xFFFD_u16])
      encoded.unsafe_fetch(encoded.size).should eq 0_u16
    end
  end

  describe ".from_utf16" do
    it "in the range U+0000..U+D7FF" do
      input = Slice[0_u16, 0x68_u16, 0x65_u16, 0x6c_u16, 0x6c_u16, 0x6f_u16, 0xd7ff_u16]
      String.from_utf16(input).should eq("\u{0}hello\u{d7ff}")
      String.from_utf16(input.to_unsafe).should eq({"", input.to_unsafe + 1})
    end

    it "in the range U+E000 to U+FFFF" do
      input = Slice[0xe000_u16, 0xffff_u16]
      String.from_utf16(input).should eq("\u{e000}\u{ffff}")

      pointer = Slice[0xe000_u16, 0xffff_u16, 0_u16].to_unsafe
      String.from_utf16(pointer).should eq({"\u{e000}\u{ffff}", pointer + 3})
    end

    it "in the range U+10000..U+10FFFF" do
      input = Slice[0xd800_u16, 0xdc00_u16]
      String.from_utf16(input).should eq("\u{10000}")

      pointer = Slice[0xd800_u16, 0xdc00_u16, 0_u16].to_unsafe
      String.from_utf16(pointer).should eq({"\u{10000}", pointer + 3})
    end

    it "in the range U+D800..U+DFFF" do
      input = Slice[0xdc00_u16, 0xd800_u16]
      String.from_utf16(input).should eq("\u{fffd}\u{fffd}")

      pointer = Slice[0xdc00_u16, 0xd800_u16, 0_u16].to_unsafe
      String.from_utf16(pointer).should eq({"\u{fffd}\u{fffd}", pointer + 3})
    end

    it "handles null bytes" do
      slice = Slice[104_u16, 105_u16, 0_u16, 55296_u16, 56485_u16]
      String.from_utf16(slice).should eq("hi\0000𐂥")
      String.from_utf16(slice.to_unsafe).should eq({"hi", slice.to_unsafe + 3})
    end

    it "with pointer reads multiple strings" do
      input = Slice[0_u16, 0x68_u16, 0x65_u16, 0x6c_u16, 0x6c_u16, 0x6f_u16, 0xd7ff_u16, 0_u16]
      pointer = input.to_unsafe
      string, pointer = String.from_utf16(pointer)
      string.should eq("")
      string, pointer = String.from_utf16(pointer)
      string.should eq("hello\u{d7ff}")
    end
  end
end
