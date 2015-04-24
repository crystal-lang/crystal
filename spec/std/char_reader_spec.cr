require "spec"
require "char_reader"

describe "CharReader" do
  it "iterates through empty string" do
    reader = CharReader.new("")
    expect(reader.pos).to eq(0)
    expect(reader.current_char.ord).to eq(0)
    expect(reader.has_next?).to be_false

    expect_raises IndexOutOfBounds do
      reader.next_char
    end
  end

  it "iterates through string of length one" do
    reader = CharReader.new("a")
    expect(reader.pos).to eq(0)
    expect(reader.current_char).to eq('a')
    expect(reader.has_next?).to be_true
    expect(reader.next_char.ord).to eq(0)
    expect(reader.has_next?).to be_false

    expect_raises IndexOutOfBounds do
      reader.next_char
    end
  end

  it "iterates through chars" do
    reader = CharReader.new("há日本語")
    expect(reader.pos).to eq(0)
    expect(reader.current_char.ord).to eq(104)
    expect(reader.has_next?).to be_true

    expect(reader.next_char.ord).to eq(225)

    expect(reader.pos).to eq(1)
    expect(reader.current_char.ord).to eq(225)

    expect(reader.next_char.ord).to eq(26085)
    expect(reader.next_char.ord).to eq(26412)
    expect(reader.next_char.ord).to eq(35486)
    expect(reader.has_next?).to be_true

    expect(reader.next_char.ord).to eq(0)
    expect(reader.has_next?).to be_false

    expect_raises IndexOutOfBounds do
      reader.next_char
    end
  end

  it "peeks next char" do
    reader = CharReader.new("há日本語")
    expect(reader.peek_next_char.ord).to eq(225)
  end

  it "sets pos" do
    reader = CharReader.new("há日本語")
    reader.pos = 1
    expect(reader.pos).to eq(1)
    expect(reader.current_char.ord).to eq(225)
  end

  it "is an Enumerable(Char)" do
    reader = CharReader.new("abc")
    sum = 0
    reader.each do |char|
      sum += char.ord
    end
    expect(sum).to eq(294)
  end

  it "is an Enumerable(Char) but doesn't yield if empty" do
    reader = CharReader.new("")
    reader.each do |char|
      fail "reader each shouldn't yield on empty string"
    end
  end

  it "errors if 0x80 <= first_byte < 0xC2" do
    expect_raises { CharReader.new(String.new [0x80_u8].buffer) }
    expect_raises { CharReader.new(String.new [0xC1_u8].buffer) }
  end

  it "errors if (second_byte & 0xC0) != 0x80" do
    expect_raises { CharReader.new(String.new [0xd0_u8, 0_u8].buffer) }
  end

  it "errors if first_byte == 0xE0 && second_byte < 0xA0" do
    expect_raises { CharReader.new(String.new [0xe0_u8, 0x9F_u8, 0xA0_u8].buffer) }
  end

  it "errors if first_byte < 0xF0 && (third_byte & 0xC0) != 0x80" do
    expect_raises { CharReader.new(String.new [0xe0_u8, 0xA0_u8, 0_u8].buffer) }
  end

  it "errors if first_byte == 0xF0 && second_byte < 0x90" do
    expect_raises { CharReader.new(String.new [0xf0_u8, 0x8F_u8, 0xA0_u8].buffer) }
  end

  it "errors if first_byte == 0xF4 && second_byte >= 0x90" do
    expect_raises { CharReader.new(String.new [0xf4_u8, 0x90_u8, 0xA0_u8].buffer) }
  end

  it "errors if first_byte < 0xF5 && (fourth_byte & 0xC0) != 0x80" do
    expect_raises { CharReader.new(String.new [0xf4_u8, 0x8F_u8, 0xA0_u8, 0_u8].buffer) }
  end

  it "errors if first_byte >= 0xF5" do
    expect_raises { CharReader.new(String.new [0xf5_u8, 0x8F_u8, 0xA0_u8, 0xA0_u8].buffer) }
  end
end
