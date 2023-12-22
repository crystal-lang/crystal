require "spec"
require "char/reader"

private def assert_invalid_byte_sequence(bytes, *, file = __FILE__, line = __LINE__)
  reader = Char::Reader.new(String.new bytes)
  reader.current_char.should eq(Char::REPLACEMENT), file: file, line: line
  reader.current_char_width.should eq(1), file: file, line: line
  reader.error.should eq(bytes[0]), file: file, line: line
end

private def assert_reads_at_end(bytes, *, file = __FILE__, line = __LINE__)
  str = String.new bytes
  reader = Char::Reader.new(str, pos: bytes.size)
  reader.previous_char
  reader.current_char.should eq(str[0]), file: file, line: line
  reader.current_char_width.should eq(bytes.size), file: file, line: line
  reader.pos.should eq(0), file: file, line: line
  reader.error.should be_nil, file: file, line: line
end

private def assert_invalid_byte_sequence_at_end(bytes, *, file = __FILE__, line = __LINE__)
  str = String.new bytes
  reader = Char::Reader.new(str, pos: bytes.size)
  reader.previous_char
  reader.current_char.should eq(Char::REPLACEMENT), file: file, line: line
  reader.current_char_width.should eq(1), file: file, line: line
  reader.pos.should eq(bytes.size - 1), file: file, line: line
  reader.error.should eq(bytes[-1]), file: file, line: line
end

describe "Char::Reader" do
  it "iterates through empty string" do
    reader = Char::Reader.new("")
    reader.pos.should eq(0)
    reader.current_char.ord.should eq(0)
    reader.error.should be_nil
    reader.has_next?.should be_false

    expect_raises IndexError do
      reader.next_char
    end
  end

  it "iterates through string of size one" do
    reader = Char::Reader.new("a")
    reader.pos.should eq(0)
    reader.current_char.should eq('a')
    reader.has_next?.should be_true
    reader.next_char.ord.should eq(0)
    reader.has_next?.should be_false

    expect_raises IndexError do
      reader.next_char
    end
  end

  it "iterates through chars" do
    reader = Char::Reader.new("há日本語")
    reader.pos.should eq(0)
    reader.current_char.ord.should eq(104)
    reader.has_next?.should be_true

    reader.next_char.ord.should eq(225)

    reader.pos.should eq(1)
    reader.current_char.ord.should eq(225)

    reader.next_char.ord.should eq(26085)
    reader.next_char.ord.should eq(26412)
    reader.next_char.ord.should eq(35486)
    reader.has_next?.should be_true

    reader.next_char.ord.should eq(0)
    reader.has_next?.should be_false

    expect_raises IndexError do
      reader.next_char
    end
  end

  it "peeks next char" do
    reader = Char::Reader.new("há日本語")
    reader.peek_next_char.ord.should eq(225)
  end

  it "sets pos" do
    reader = Char::Reader.new("há日本語")
    reader.pos = 1
    reader.pos.should eq(1)
    reader.current_char.ord.should eq(225)
  end

  describe "#each" do
    it "yields chars" do
      reader = Char::Reader.new("abc")
      chars = [] of Char
      reader.each do |char|
        chars << char
      end.should be_nil
      chars.should eq ['a', 'b', 'c']
    end

    it "does not yield if empty" do
      reader = Char::Reader.new("")
      reader.each do |char|
        fail "reader each shouldn't yield on empty string"
      end.should be_nil
    end

    it "checks bounds after block" do
      string = "f"
      reader = Char::Reader.new(string)
      reader.each do |c|
        c.should eq 'f'
        reader.next_char
      end
    end
  end

  it "starts at end" do
    reader = Char::Reader.new(at_end: "")
    reader.pos.should eq(0)
    reader.current_char.ord.should eq(0)
    reader.has_previous?.should be_false
    reader.has_next?.should be_false
  end

  it "gets previous char (ascii)" do
    reader = Char::Reader.new(at_end: "hello")
    reader.pos.should eq(4)
    reader.current_char.should eq('o')
    reader.has_previous?.should be_true
    reader.has_next?.should be_true

    reader.previous_char.should eq('l')
    reader.has_next?.should be_true
    reader.previous_char.should eq('l')
    reader.previous_char.should eq('e')
    reader.previous_char.should eq('h')
    reader.has_previous?.should be_false

    expect_raises IndexError do
      reader.previous_char
    end
  end

  it "gets previous char (unicode)" do
    reader = Char::Reader.new(at_end: "há日本語")
    reader.pos.should eq(9)
    reader.current_char.should eq('語')
    reader.has_previous?.should be_true
    reader.has_next?.should be_true

    reader.previous_char.should eq('本')
    reader.has_next?.should be_true
    reader.previous_char.should eq('日')
    reader.previous_char.should eq('á')
    reader.previous_char.should eq('h')
    reader.has_previous?.should be_false
  end

  it "starts at pos" do
    reader = Char::Reader.new("há日本語", pos: 9)
    reader.pos.should eq(9)
    reader.current_char.should eq('語')
  end

  it "#current_char?" do
    reader = Char::Reader.new("há日本語")
    reader.current_char?.should eq('h')
    reader.next_char
    reader.current_char?.should eq('á')
    reader.next_char
    reader.current_char?.should eq('日')
    reader.next_char
    reader.current_char?.should eq('本')
    reader.next_char
    reader.current_char?.should eq('語')
    reader.next_char
    reader.current_char?.should be_nil
    reader.previous_char
    reader.current_char?.should eq('語')
  end

  it "#next_char?" do
    reader = Char::Reader.new("há日本語")
    reader.next_char?.should eq('á')
    reader.pos.should eq(1)
    reader.next_char?.should eq('日')
    reader.pos.should eq(3)
    reader.next_char?.should eq('本')
    reader.pos.should eq(6)
    reader.next_char?.should eq('語')
    reader.pos.should eq(9)
    reader.next_char?.should be_nil
    reader.pos.should eq(12)
    reader.next_char?.should be_nil
    reader.pos.should eq(12)
  end

  it "#previous_char?" do
    reader = Char::Reader.new("há日本語", pos: 12)
    reader.previous_char?.should eq('語')
    reader.pos.should eq(9)
    reader.previous_char?.should eq('本')
    reader.pos.should eq(6)
    reader.previous_char?.should eq('日')
    reader.pos.should eq(3)
    reader.previous_char?.should eq('á')
    reader.pos.should eq(1)
    reader.previous_char?.should eq('h')
    reader.pos.should eq(0)
    reader.previous_char?.should be_nil
    reader.pos.should eq(0)
  end

  it "errors if 0x80 <= first_byte < 0xC2" do
    assert_invalid_byte_sequence Bytes[0x80]
    assert_invalid_byte_sequence Bytes[0xC1]
  end

  it "errors if (second_byte & 0xC0) != 0x80" do
    assert_invalid_byte_sequence Bytes[0xd0]
  end

  it "errors if first_byte == 0xE0 && second_byte < 0xA0" do
    assert_invalid_byte_sequence Bytes[0xe0, 0x9F, 0xA0]
  end

  it "errors if first_byte == 0xED && second_byte >= 0xA0" do
    assert_invalid_byte_sequence Bytes[0xed, 0xB0, 0xA0]
  end

  it "errors if first_byte < 0xF0 && (third_byte & 0xC0) != 0x80" do
    assert_invalid_byte_sequence Bytes[0xe0, 0xA0, 0]
  end

  it "errors if first_byte == 0xF0 && second_byte < 0x90" do
    assert_invalid_byte_sequence Bytes[0xf0, 0x8F, 0xA0]
  end

  it "errors if first_byte == 0xF4 && second_byte >= 0x90" do
    assert_invalid_byte_sequence Bytes[0xf4, 0x90, 0xA0]
  end

  it "errors if first_byte < 0xF5 && (fourth_byte & 0xC0) != 0x80" do
    assert_invalid_byte_sequence Bytes[0xf4, 0x8F, 0xA0, 0]
  end

  it "errors if first_byte >= 0xF5" do
    assert_invalid_byte_sequence Bytes[0xf5, 0x8F, 0xA0, 0xA0]
  end

  it "errors if second_byte is out of bounds" do
    assert_invalid_byte_sequence Bytes[0xf4]
  end

  it "errors if third_byte is out of bounds" do
    assert_invalid_byte_sequence Bytes[0xf4, 0x8f]
  end

  it "errors if fourth_byte is out of bounds" do
    assert_invalid_byte_sequence Bytes[0xf4, 0x8f, 0xa0]
  end

  describe "#previous_char" do
    it "reads on valid UTF-8" do
      assert_reads_at_end Bytes[0x00]
      assert_reads_at_end Bytes[0x7f]

      assert_reads_at_end Bytes[0xc2, 0x80]
      assert_reads_at_end Bytes[0xc2, 0xbf]
      assert_reads_at_end Bytes[0xdf, 0x80]
      assert_reads_at_end Bytes[0xdf, 0xbf]

      assert_reads_at_end Bytes[0xe1, 0x80, 0x80]
      assert_reads_at_end Bytes[0xe1, 0x80, 0xbf]
      assert_reads_at_end Bytes[0xe1, 0x9f, 0x80]
      assert_reads_at_end Bytes[0xe1, 0x9f, 0xbf]
      assert_reads_at_end Bytes[0xed, 0x80, 0x80]
      assert_reads_at_end Bytes[0xed, 0x80, 0xbf]
      assert_reads_at_end Bytes[0xed, 0x9f, 0x80]
      assert_reads_at_end Bytes[0xed, 0x9f, 0xbf]
      assert_reads_at_end Bytes[0xef, 0x80, 0x80]
      assert_reads_at_end Bytes[0xef, 0x80, 0xbf]
      assert_reads_at_end Bytes[0xef, 0x9f, 0x80]
      assert_reads_at_end Bytes[0xef, 0x9f, 0xbf]

      assert_reads_at_end Bytes[0xe0, 0xa0, 0x80]
      assert_reads_at_end Bytes[0xe0, 0xa0, 0xbf]
      assert_reads_at_end Bytes[0xe0, 0xbf, 0x80]
      assert_reads_at_end Bytes[0xe0, 0xbf, 0xbf]
      assert_reads_at_end Bytes[0xe1, 0xa0, 0x80]
      assert_reads_at_end Bytes[0xe1, 0xa0, 0xbf]
      assert_reads_at_end Bytes[0xe1, 0xbf, 0x80]
      assert_reads_at_end Bytes[0xe1, 0xbf, 0xbf]
      assert_reads_at_end Bytes[0xef, 0xa0, 0x80]
      assert_reads_at_end Bytes[0xef, 0xa0, 0xbf]
      assert_reads_at_end Bytes[0xef, 0xbf, 0x80]
      assert_reads_at_end Bytes[0xef, 0xbf, 0xbf]

      assert_reads_at_end Bytes[0xf1, 0x80, 0x80, 0x80]
      assert_reads_at_end Bytes[0xf1, 0x8f, 0x80, 0x80]
      assert_reads_at_end Bytes[0xf4, 0x80, 0x80, 0x80]
      assert_reads_at_end Bytes[0xf4, 0x8f, 0x80, 0x80]

      assert_reads_at_end Bytes[0xf0, 0x90, 0x80, 0x80]
      assert_reads_at_end Bytes[0xf0, 0xbf, 0x80, 0x80]
      assert_reads_at_end Bytes[0xf3, 0x90, 0x80, 0x80]
      assert_reads_at_end Bytes[0xf3, 0xbf, 0x80, 0x80]
    end

    it "errors on invalid UTF-8" do
      assert_invalid_byte_sequence_at_end Bytes[0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xbf]
      assert_invalid_byte_sequence_at_end Bytes[0xc0]
      assert_invalid_byte_sequence_at_end Bytes[0xff]

      assert_invalid_byte_sequence_at_end Bytes[0x00, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x7f, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x9f, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xbf, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc1, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xe0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xff, 0x80]

      assert_invalid_byte_sequence_at_end Bytes[0x00, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x7f, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x80, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x8f, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x90, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xbf, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc0, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc1, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc2, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xdf, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xe0, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xe0, 0x9f, 0xbf]
      assert_invalid_byte_sequence_at_end Bytes[0xf0, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xff, 0x80, 0x80]

      assert_invalid_byte_sequence_at_end Bytes[0x00, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x7f, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x80, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x8f, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0x90, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xbf, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc0, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc1, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xc2, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xdf, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xed, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xed, 0xbf, 0xbf]
      assert_invalid_byte_sequence_at_end Bytes[0xf0, 0xa0, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xff, 0xa0, 0x80]

      assert_invalid_byte_sequence_at_end Bytes[0x00, 0x80, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xef, 0x80, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xf0, 0x80, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xf5, 0x80, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xff, 0x80, 0x80, 0x80]

      assert_invalid_byte_sequence_at_end Bytes[0x00, 0x90, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xef, 0x90, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xf4, 0x90, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xf5, 0x90, 0x80, 0x80]
      assert_invalid_byte_sequence_at_end Bytes[0xff, 0x90, 0x80, 0x80]
    end
  end
end
