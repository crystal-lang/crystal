#!/usr/bin/env bin/crystal -run
require "spec"

describe "Char" do
  describe "upcase" do
    assert { 'a'.upcase.should eq('A') }
    assert { '1'.upcase.should eq('1') }
  end

  describe "downcase" do
    assert { 'A'.downcase.should eq('a') }
    assert { '1'.downcase.should eq('1') }
  end

  describe "whitespace?" do
    [' ', '\t', '\n', '\v', '\f', '\r'].each do |char|
      assert { char.whitespace?.should be_true }
    end
  end

  describe "inspect" do
    'a'.inspect.should eq("'a'")
  end

  it "escapes chars" do
    '\t'.ord.should eq(9)
    '\n'.ord.should eq(10)
    '\v'.ord.should eq(11)
    '\f'.ord.should eq(12)
    '\r'.ord.should eq(13)
    '\''.ord.should eq(39)
    '\\'.ord.should eq(92)
    '\0'.ord.should eq(0)
    '\3'.ord.should eq(3)
    '\23'.ord.should eq((2 * 8) + 3)
    '\123'.ord.should eq((1 * 8 * 8) + (2 * 8) + 3)
    '\033'.ord.should eq((3 * 8) + 3)
  end
end
