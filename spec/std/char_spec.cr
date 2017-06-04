require "spec"
require "unicode"

describe "Char" do
  describe "upcase" do
    it { 'a'.upcase.should eq('A') }
    it { '1'.upcase.should eq('1') }
  end

  describe "downcase" do
    it { 'A'.downcase.should eq('a') }
    it { '1'.downcase.should eq('1') }
    it do
      actual = [] of Char
      'ß'.downcase(Unicode::CaseOptions::Fold) { |c| actual << c }
      actual.should eq(['s', 's'])
    end
    it { 'Ń'.downcase(Unicode::CaseOptions::Fold).should eq('ń') }
  end

  describe "succ" do
    it { 'a'.succ.should eq('b') }
    it { 'あ'.succ.should eq('ぃ') }
  end

  describe "pred" do
    it { 'b'.pred.should eq('a') }
    it { 'ぃ'.pred.should eq('あ') }
  end

  describe "+" do
    it { ('a' + 2).should eq('c') }
  end

  describe "-" do
    it { ('c' - 2).should eq('a') }
  end

  describe "ascii_uppercase?" do
    it { 'a'.ascii_uppercase?.should be_false }
    it { 'A'.ascii_uppercase?.should be_true }
    it { '1'.ascii_uppercase?.should be_false }
    it { ' '.ascii_uppercase?.should be_false }
  end

  describe "uppercase?" do
    it { 'A'.uppercase?.should be_true }
    it { 'Á'.uppercase?.should be_true }
    it { 'Ā'.uppercase?.should be_true }
    it { 'Ą'.uppercase?.should be_true }
    it { 'ā'.uppercase?.should be_false }
    it { 'á'.uppercase?.should be_false }
    it { 'a'.uppercase?.should be_false }
    it { '1'.uppercase?.should be_false }
    it { ' '.uppercase?.should be_false }
  end

  describe "ascii_lowercase?" do
    it { 'a'.ascii_lowercase?.should be_true }
    it { 'A'.ascii_lowercase?.should be_false }
    it { '1'.ascii_lowercase?.should be_false }
    it { ' '.ascii_lowercase?.should be_false }
  end

  describe "lowercase?" do
    it { 'a'.lowercase?.should be_true }
    it { 'á'.lowercase?.should be_true }
    it { 'ā'.lowercase?.should be_true }
    it { 'ă'.lowercase?.should be_true }
    it { 'A'.lowercase?.should be_false }
    it { 'Á'.lowercase?.should be_false }
    it { '1'.lowercase?.should be_false }
    it { ' '.lowercase?.should be_false }
  end

  describe "ascii_letter?" do
    it { 'a'.ascii_letter?.should be_true }
    it { 'A'.ascii_letter?.should be_true }
    it { '1'.ascii_letter?.should be_false }
    it { ' '.ascii_letter?.should be_false }
  end

  describe "alphanumeric?" do
    it { 'a'.alphanumeric?.should be_true }
    it { 'A'.alphanumeric?.should be_true }
    it { '1'.alphanumeric?.should be_true }
    it { ' '.alphanumeric?.should be_false }
  end

  describe "ascii_whitespace?" do
    [' ', '\t', '\n', '\v', '\f', '\r'].each do |char|
      it { char.ascii_whitespace?.should be_true }
    end
    it { 'A'.ascii_whitespace?.should be_false }
  end

  describe "hex?" do
    "0123456789abcdefABCDEF".each_char do |char|
      it { char.hex?.should be_true }
    end
    ('g'..'z').each do |char|
      it { char.hex?.should be_false }
    end
    [' ', '-', '\0'].each do |char|
      it { char.hex?.should be_false }
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
    'á'.dump.should eq("'\\u{e1}'")
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

  it "escapes with unicode" do
    '\u{12}'.ord.should eq(1 * 16 + 2)
    '\u{A}'.ord.should eq(10)
    '\u{AB}'.ord.should eq(10 * 16 + 11)
  end

  it "does to_i without a base" do
    ('0'..'9').each_with_index do |c, i|
      c.to_i.should eq(i)
    end
    expect_raises(ArgumentError) { 'a'.to_i }
    'a'.to_i?.should be_nil

    '1'.to_i8.should eq(1i8)
    '1'.to_i16.should eq(1i16)
    '1'.to_i32.should eq(1i32)
    '1'.to_i64.should eq(1i64)

    expect_raises(ArgumentError) { 'a'.to_i8 }
    expect_raises(ArgumentError) { 'a'.to_i16 }
    expect_raises(ArgumentError) { 'a'.to_i32 }
    expect_raises(ArgumentError) { 'a'.to_i64 }

    'a'.to_i8?.should be_nil
    'a'.to_i16?.should be_nil
    'a'.to_i32?.should be_nil
    'a'.to_i64?.should be_nil

    '1'.to_u8.should eq(1u8)
    '1'.to_u16.should eq(1u16)
    '1'.to_u32.should eq(1u32)
    '1'.to_u64.should eq(1u64)

    expect_raises(ArgumentError) { 'a'.to_u8 }
    expect_raises(ArgumentError) { 'a'.to_u16 }
    expect_raises(ArgumentError) { 'a'.to_u32 }
    expect_raises(ArgumentError) { 'a'.to_u64 }

    'a'.to_u8?.should be_nil
    'a'.to_u16?.should be_nil
    'a'.to_u32?.should be_nil
    'a'.to_u64?.should be_nil
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
    expect_raises(ArgumentError) { 'Z'.to_i(16) }
    'Z'.to_i?(16).should be_nil
  end

  it "does to_i with base 36" do
    letters = ('0'..'9').each.chain(('a'..'z').each).chain(('A'..'Z').each)
    nums = (0..9).each.chain((10..35).each).chain((10..35).each)
    letters.zip(nums).each do |(letter, num)|
      letter.to_i(36).should eq(num)
    end
  end

  it "to_i rejects unsupported base (1)" do
    expect_raises ArgumentError, "Invalid base 1" do
      '0'.to_i(1)
    end
  end

  it "to_i rejects unsupported base (37)" do
    expect_raises ArgumentError, "Invalid base 37" do
      '0'.to_i(37)
    end
  end

  it "does to_f" do
    ('0'..'9').each.zip((0..9).each).each do |c, i|
      c.to_f.should eq(i.to_f)
    end
    expect_raises(ArgumentError) { 'A'.to_f }
    '1'.to_f32.should eq(1.0f32)
    '1'.to_f64.should eq(1.0f64)
    'a'.to_f?.should be_nil
    'a'.to_f32?.should be_nil
    'a'.to_f64?.should be_nil
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
    it { "foo".index('o').should eq(1) }
    it { "foo".index('x').should be_nil }
  end

  it "does <=>" do
    ('a' <=> 'b').should be < 0
    ('a' <=> 'a').should eq(0)
    ('b' <=> 'a').should be > 0
  end

  describe "+" do
    it "does for both ascii" do
      str = 'f' + "oo"
      str.bytesize.should eq(3)
      str.@length.should eq(3)
      str.should eq("foo")
    end

    it "does for both unicode" do
      str = '青' + "旅路"
      str.@length.should eq(3)
      str.should eq("青旅路")
    end
  end

  describe "bytesize" do
    it "does for ascii" do
      'a'.bytesize.should eq(1)
    end

    it "does for unicode" do
      '青'.bytesize.should eq(3)
    end

    it "raises on codepoint bigger than 0x10ffff" do
      expect_raises InvalidByteSequenceError do
        (0x10ffff + 1).unsafe_chr.bytesize
      end
    end
  end

  describe "in_set?" do
    it { 'a'.in_set?("a").should be_true }
    it { 'a'.in_set?("b").should be_false }
    it { 'a'.in_set?("a-c").should be_true }
    it { 'b'.in_set?("a-c").should be_true }
    it { 'c'.in_set?("a-c").should be_true }
    it { 'c'.in_set?("a-bc").should be_true }
    it { 'b'.in_set?("a-bc").should be_true }
    it { 'd'.in_set?("a-c").should be_false }
    it { 'b'.in_set?("^a-c").should be_false }
    it { 'd'.in_set?("^a-c").should be_true }
    it { 'a'.in_set?("ab-c").should be_true }
    it { 'a'.in_set?("\\^ab-c").should be_true }
    it { '^'.in_set?("\\^ab-c").should be_true }
    it { '^'.in_set?("a^b-c").should be_true }
    it { '^'.in_set?("ab-c^").should be_true }
    it { '^'.in_set?("a0-^").should be_true }
    it { '^'.in_set?("^-c").should be_true }
    it { '^'.in_set?("a^-c").should be_true }
    it { '\\'.in_set?("ab-c\\").should be_true }
    it { '\\'.in_set?("a\\b-c").should be_false }
    it { '\\'.in_set?("a0-\\c").should be_true }
    it { '\\'.in_set?("a\\-c").should be_false }
    it { '-'.in_set?("a-c").should be_false }
    it { '-'.in_set?("a-c").should be_false }
    it { '-'.in_set?("a\\-c").should be_true }
    it { '-'.in_set?("-c").should be_true }
    it { '-'.in_set?("a-").should be_true }
    it { '-'.in_set?("^-c").should be_false }
    it { '-'.in_set?("^\\-c").should be_false }
    it { 'b'.in_set?("^\\-c").should be_true }
    it { '-'.in_set?("a^-c").should be_false }
    it { 'a'.in_set?("a", "ab").should be_true }
    it { 'a'.in_set?("a", "^b").should be_true }
    it { 'a'.in_set?("a", "b").should be_false }
    it { 'a'.in_set?("ab", "ac", "ad").should be_true }

    it "rejects invalid ranges" do
      expect_raises do
        'a'.in_set?("c-a")
      end
    end
  end

  it "raises on codepoint bigger than 0x10ffff when doing each_byte" do
    expect_raises InvalidByteSequenceError do
      (0x10ffff + 1).unsafe_chr.each_byte { |b| }
    end
  end

  it "does each_byte" do
    'a'.each_byte(&.should eq('a'.ord)).should be_nil
  end

  it "does bytes" do
    '\u{FF}'.bytes.should eq([195, 191])
  end

  it "#===(:Int)" do
    ('c'.ord).should eq(99)
    ('c' === 99_u8).should be_true
    ('c' === 99).should be_true
    ('z' === 99).should be_false

    ('酒'.ord).should eq(37202)
    ('酒' === 37202).should be_true
  end

  it "does ascii_number?" do
    256.times do |i|
      chr = i.chr
      ("01".chars.includes?(chr) == chr.ascii_number?(2)).should be_true
      ("01234567".chars.includes?(chr) == chr.ascii_number?(8)).should be_true
      ("0123456789".chars.includes?(chr) == chr.ascii_number?).should be_true
      ("0123456789".chars.includes?(chr) == chr.ascii_number?(10)).should be_true
      ("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".includes?(chr) == chr.ascii_number?(36)).should be_true
      unless 2 <= i <= 36
        expect_raises ArgumentError do
          '0'.ascii_number?(i)
        end
      end
    end
  end

  it "does number?" do
    it { '1'.number?.should be_true }
    it { '٠'.number?.should be_true }
    it { '٢'.number?.should be_true }
    it { 'a'.number?.should be_false }
  end

  it "does ascii_control?" do
    'ù'.ascii_control?.should be_false
    'a'.ascii_control?.should be_false
    '\u0019'.ascii_control?.should be_true
  end

  it "does mark?" do
    0x300.chr.mark?.should be_true
  end

  it "does ascii?" do
    'a'.ascii?.should be_true
    127.chr.ascii?.should be_true
    128.chr.ascii?.should be_false
    '酒'.ascii?.should be_false
  end

  describe "clone" do
    it { 'a'.clone.should eq('a') }
  end
end
