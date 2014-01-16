#!/usr/bin/env bin/crystal -run
require "spec"
require "char_reader"

describe "CharReader" do
  it "iterates through chars" do
    reader = CharReader.new("há日本語")
    reader.pos.should eq(0)
    reader.current_char.ord.should eq(104)

    reader.next_char.ord.should eq(225)

    reader.pos.should eq(1)
    reader.current_char.ord.should eq(225)

    reader.next_char.ord.should eq(26085)
    reader.next_char.ord.should eq(26412)
    reader.next_char.ord.should eq(35486)
    reader.next_char.ord.should eq(0)

    begin
      reader.next_char
      fail "expected to raise IndexOutOfBounds"
    rescue IndexOutOfBounds
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
end
