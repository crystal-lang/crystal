require "spec"
require "char_reader"

describe "CharReader" do
  it "iterates through empty string" do
    reader = CharReader.new("")
    reader.pos.should eq(0)
    reader.current_char.ord.should eq(0)
    reader.has_next?.should be_false

    expect_raises IndexOutOfBounds do
      reader.next_char
    end
  end

  it "iterates through string of length one" do
    reader = CharReader.new("a")
    reader.pos.should eq(0)
    reader.current_char.should eq('a')
    reader.has_next?.should be_true
    reader.next_char.ord.should eq(0)
    reader.has_next?.should be_false

    expect_raises IndexOutOfBounds do
      reader.next_char
    end
  end

  it "iterates through chars" do
    reader = CharReader.new("há日本語")
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

    expect_raises IndexOutOfBounds do
      reader.next_char
    end
  end

  it "peeks next char" do
    reader = CharReader.new("há日本語")
    reader.peek_next_char.ord.should eq(225)
  end

  it "sets pos" do
    reader = CharReader.new("há日本語")
    reader.pos = 1
    reader.pos.should eq(1)
    reader.current_char.ord.should eq(225)
  end

  it "is an Enumerable(Char)" do
    reader = CharReader.new("abc")
    sum = 0
    reader.each do |char|
      sum += char.ord
    end
    sum.should eq(294)
  end

  it "is an Enumerable(Char) but doesn't yield if empty" do
    reader = CharReader.new("")
    reader.each do |char|
      fail "reader each shouldn't yield on empty string"
    end
  end
end
