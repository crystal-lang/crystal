#!/usr/bin/env bin/crystal -run
require "spec"
require "char_reader"

describe "CharReader" do
  it "iterates through chars" do
    reader = CharReader.new("há日本語")
    reader.pos.should eq(0)
    reader.current_char.should eq(104)

    reader.next_char.should eq(225)

    reader.pos.should eq(1)
    reader.current_char.should eq(225)

    reader.next_char.should eq(26085)
    reader.next_char.should eq(26412)
    reader.next_char.should eq(35486)
    reader.next_char.should eq(0)

    begin
      reader.next_char
      fail "expected to raise IndexOutOfBounds"
    rescue IndexOutOfBounds
    end
  end
end
