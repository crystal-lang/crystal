require "spec"
require "char/reader"
require "../../support/string"

private def assert_invalid_byte_sequence(bytes, *, file = __FILE__, line = __LINE__)
  reader = Char::Reader.new("#{String.new(bytes)}Z")
  bytes.each_with_index do |byte, i|
    if byte.zero?
      reader.current_char.should eq('\0'), file: file, line: line
      reader.current_char?.should eq('\0'), file: file, line: line
      reader.error.should be_nil, file: file, line: line
    else
      reader.current_char.should eq(Char::REPLACEMENT), file: file, line: line
      reader.current_char?.should eq(Char::REPLACEMENT), file: file, line: line
      reader.error.should eq(byte), file: file, line: line
    end
    reader.current_char_width.should eq(1), file: file, line: line
    reader.pos.should eq(i), file: file, line: line
    reader.has_next?.should be_true, file: file, line: line

    reader.next_char
  end

  reader.current_char.should eq('Z'), file: file, line: line
  reader.error.should be_nil, file: file, line: line
end

private def assert_invalid_byte_sequence_at_end(bytes, *, file = __FILE__, line = __LINE__)
  str = String.new bytes
  reader = Char::Reader.new(str, pos: bytes.size)
  reader.previous_char
  reader.current_char.should eq(Char::REPLACEMENT), file: file, line: line
  reader.current_char?.should eq(Char::REPLACEMENT), file: file, line: line
  reader.current_char_width.should eq(1), file: file, line: line
  reader.pos.should eq(bytes.size - 1), file: file, line: line
  reader.error.should eq(bytes[-1]), file: file, line: line
end

private def assert_at_end(reader)
  reader.current_char.should eq '\0'
  reader.current_char?.should be_nil
  reader.pos.should eq reader.string.bytesize

  reader.has_next?.should be_false

  reader.next_char?.should be_nil
  expect_raises IndexError do
    reader.next_char
  end
  expect_raises IndexError do
    reader.peek_next_char
  end
end

private def assert_at_start(reader)
  reader.pos.should eq 0

  reader.has_previous?.should be_false

  reader.previous_char?.should be_nil
  expect_raises IndexError do
    reader.previous_char
  end
end

private def assert_current_char(reader, char)
  reader.current_char.should eq char
  reader.current_char?.should eq char
  reader.current_char_width.should eq char.bytesize

  reader.pos.should be < reader.string.bytesize
  reader.has_next?.should be_true
end

private def assert_next_char(reader, char)
  reader.has_next?.should be_true
  next_pos = reader.pos + reader.current_char_width
  reader_dup = reader.dup
  reader_dup2 = reader.dup

  reader.next_char.should eq char
  reader.pos.should eq next_pos

  reader_dup.next_char?.should eq char
  reader_dup.pos.should eq next_pos

  reader_dup2.pos = next_pos

  assert_current_char(reader, char)
  assert_current_char(reader_dup, char)
  assert_current_char(reader_dup2, char)

  reader
end

private def assert_previous_char(reader, char)
  reader.has_previous?.should be_true
  start_pos = reader.pos
  reader_dup = reader.dup
  reader_dup2 = reader.dup

  reader.previous_char.should eq char
  reader.pos.should eq start_pos - reader.current_char_width

  reader_dup.previous_char?.should eq char
  reader_dup.pos.should eq reader.pos

  reader_dup2.pos = reader.pos

  assert_current_char(reader, char)
  assert_current_char(reader_dup, char)
  assert_current_char(reader_dup2, char)

  reader
end

describe "Char::Reader" do
  describe ".new" do
    it "starts at pos" do
      reader = Char::Reader.new("há日本語", pos: 9)
      reader.pos.should eq(9)
      reader.current_char.should eq('語')
    end

    it "starts at end" do
      reader = Char::Reader.new(at_end: "")
      reader.pos.should eq(0)
      reader.current_char.should eq '\0'
      reader.has_previous?.should be_false
      reader.has_next?.should be_false
    end
  end

  it "iterates through empty string" do
    reader = Char::Reader.new("")
    reader.pos.should eq(0)
    reader.current_char.should eq '\0'
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
    reader.next_char.should eq '\0'
    reader.has_next?.should be_false

    expect_raises IndexError do
      reader.next_char
    end
    expect_raises IndexError do
      reader.peek_next_char
    end
  end

  it "iterates through chars" do
    reader = Char::Reader.new("há日本語")
    reader.pos.should eq(0)
    reader.current_char.should eq('h')
    reader.has_next?.should be_true

    reader.next_char.should eq('á')

    reader.pos.should eq(1)
    reader.current_char.should eq('á')

    reader.next_char.should eq('日')
    reader.next_char.should eq('本')
    reader.next_char.should eq('語')
    reader.has_next?.should be_true

    reader.next_char.should eq '\0'
    reader.has_next?.should be_false

    expect_raises IndexError do
      reader.next_char
    end
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

      reader = Char::Reader.new(at_end: "")
      reader.each do |char|
        fail "reader each shouldn't yield on empty string"
      end.should be_nil
    end

    it "checks bounds after block" do
      string = "abc"
      reader = Char::Reader.new(string)
      chars = [] of Char
      reader.each do |c|
        chars << c
        reader.next_char
      end
      chars.should eq ['a', 'c']
    end
  end

  describe "#previous_char" do
    it "gets previous char (ascii)" do
      reader = Char::Reader.new(at_end: "hello")
      reader.pos.should eq(4)
      reader.current_char.should eq('o')

      reader = assert_previous_char(reader, 'l')
      reader = assert_previous_char(reader, 'l')
      reader = assert_previous_char(reader, 'e')
      reader = assert_previous_char(reader, 'h')

      assert_at_start(reader)
    end

    it "gets previous char (unicode)" do
      reader = Char::Reader.new(at_end: "há日本語")
      reader.pos.should eq(9)
      reader.current_char.should eq('語')

      reader = assert_previous_char(reader, '本')
      reader = assert_previous_char(reader, '日')
      reader = assert_previous_char(reader, 'á')
      reader = assert_previous_char(reader, 'h')

      assert_at_start(reader)
    end
  end

  describe "UTF-8 decoding" do
    it "parses valid UTF-8 sequences" do
      {% for _bytes, char in VALID_UTF8_BYTE_SEQUENCES %}
        reader = Char::Reader.new(at_end: ">#{{{ char.id.stringify }}}<")
        assert_previous_char(reader, {{ char }})

        reader.pos = 0
        assert_next_char(reader, {{ char }})
      {% end %}
    end

    it "errors on invalid UTF-8 sequences (next)" do
      {% for bytes in INVALID_UTF8_BYTE_SEQUENCES %}
        assert_invalid_byte_sequence Bytes{{ bytes }}
      {% end %}
    end

    it "errors on invalid UTF-8 sequences (previous)" do
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
