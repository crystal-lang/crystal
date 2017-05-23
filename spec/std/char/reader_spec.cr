require "spec"
require "char/reader"

private def assert_invalid_byte_sequence(bytes, width)
  reader = Char::Reader.new(String.new bytes)
  reader.current_char.should eq(Char::REPLACEMENT)
  reader.current_char_width.should eq(width)
  reader.error.should eq(bytes[0])
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

  it "is an Enumerable(Char)" do
    reader = Char::Reader.new("abc")
    sum = 0
    reader.each do |char|
      sum += char.ord
    end.should be_nil
    sum.should eq(294)
  end

  it "is an Enumerable(Char) but doesn't yield if empty" do
    reader = Char::Reader.new("")
    reader.each do |char|
      fail "reader each shouldn't yield on empty string"
    end.should be_nil
  end

  it "starts at end" do
    reader = Char::Reader.new(at_end: "")
    reader.pos.should eq(0)
    reader.current_char.ord.should eq(0)
    reader.has_previous?.should be_false
  end

  it "gets previous char (ascii)" do
    reader = Char::Reader.new(at_end: "hello")
    reader.pos.should eq(4)
    reader.current_char.should eq('o')
    reader.has_previous?.should be_true

    reader.previous_char.should eq('l')
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

    reader.previous_char.should eq('本')
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

  it "errors if 0x80 <= first_byte < 0xC2" do
    assert_invalid_byte_sequence Bytes[0x80], 1
    assert_invalid_byte_sequence Bytes[0xC1], 1
  end

  it "errors if (second_byte & 0xC0) != 0x80" do
    assert_invalid_byte_sequence Bytes[0xd0], 1
  end

  it "errors if first_byte == 0xE0 && second_byte < 0xA0" do
    assert_invalid_byte_sequence Bytes[0xe0, 0x9F, 0xA0], 3
  end

  it "errors if first_byte == 0xED && second_byte >= 0xA0" do
    assert_invalid_byte_sequence Bytes[0xed, 0xB0, 0xA0], 3
  end

  it "errors if first_byte < 0xF0 && (third_byte & 0xC0) != 0x80" do
    assert_invalid_byte_sequence Bytes[0xe0, 0xA0, 0], 2
  end

  it "errors if first_byte == 0xF0 && second_byte < 0x90" do
    assert_invalid_byte_sequence Bytes[0xf0, 0x8F, 0xA0], 3
  end

  it "errors if first_byte == 0xF4 && second_byte >= 0x90" do
    assert_invalid_byte_sequence Bytes[0xf4, 0x90, 0xA0], 3
  end

  it "errors if first_byte < 0xF5 && (fourth_byte & 0xC0) != 0x80" do
    assert_invalid_byte_sequence Bytes[0xf4, 0x8F, 0xA0, 0], 4
  end

  it "errors if first_byte >= 0xF5" do
    assert_invalid_byte_sequence Bytes[0xf5, 0x8F, 0xA0, 0xA0], 4
  end
end
