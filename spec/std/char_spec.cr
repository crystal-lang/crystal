#!/usr/bin/env bin/crystal --run
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

  it "dumps" do
    'a'.dump.should eq("'a'")
    '\\'.dump.should eq("'\\\\'")
    '\e'.dump.should eq("'\\e'")
    '\f'.dump.should eq("'\\f'")
    '\n'.dump.should eq("'\\n'")
    '\r'.dump.should eq("'\\r'")
    '\t'.dump.should eq("'\\t'")
    '\v'.dump.should eq("'\\v'")
    'á'.dump.should eq("'\\u{E1}'")
    '\u{81}'.dump.should eq("'\\u{81}'")
  end

  it "inspects" do
    'a'.inspect.should eq("'a'")
    '\\'.inspect.should eq("'\\\\'")
    '\e'.inspect.should eq("'\\e'")
    '\f'.inspect.should eq("'\\f'")
    '\n'.inspect.should eq("'\\n'")
    '\r'.inspect.should eq("'\\r'")
    '\t'.inspect.should eq("'\\t'")
    '\v'.inspect.should eq("'\\v'")
    'á'.inspect.should eq("'á'")
    '\u{81}'.inspect.should eq("'\\u{81}'")
  end

  it "escapes" do
    '\b'.ord.should eq(8)
    '\t'.ord.should eq(9)
    '\n'.ord.should eq(10)
    '\v'.ord.should eq(11)
    '\f'.ord.should eq(12)
    '\r'.ord.should eq(13)
    '\e'.ord.should eq(27)
    '\''.ord.should eq(39)
    '\\'.ord.should eq(92)
  end

  it "escapes with octal" do
    '\0'.ord.should eq(0)
    '\3'.ord.should eq(3)
    '\23'.ord.should eq((2 * 8) + 3)
    '\123'.ord.should eq((1 * 8 * 8) + (2 * 8) + 3)
    '\033'.ord.should eq((3 * 8) + 3)
  end

  it "escapes with unicode" do
    '\u{12}'.ord.should eq(1 * 16 + 2)
    '\u{A}'.ord.should eq(10)
    '\u{AB}'.ord.should eq(10 * 16 + 11)
  end

  it "does to_i without a base" do
    ('0'..'9').each_with_index do |c, i|
      c.to_i.should eq(i)
    end
    'a'.to_i.should eq(0)
  end

  it "does to_i with 16 base" do
    ('0'..'9').each_with_index do |c, i|
      c.to_i(16).should eq(i)
    end
    ('a'..'f').each_with_index do |c, i|
      c.to_i(16).should eq(10 + i)
    end
    ('A'..'F').each_with_index do |c, i|
      c.to_i(16).should eq(10 + i)
    end
    'Z'.to_i(16).should eq(0)
    'Z'.to_i(16, or_else: -1).should eq(-1)
  end

  it "does ord for multibyte char" do
    '日'.ord.should eq(26085)
  end

  it "does to_s for single-byte char" do
    'a'.to_s.should eq("a")
  end

  it "does to_s for multibyte char" do
    '日'.to_s.should eq("日")
  end

  describe "index" do
    assert { "foo".index('o').should eq(1) }
    assert { "foo".index('x').should be_nil }
  end

  it "does <=>" do
    ('a' <=> 'b').should be < 0
    ('a' <=> 'a').should eq(0)
    ('b' <=> 'a').should be > 0
  end
end
