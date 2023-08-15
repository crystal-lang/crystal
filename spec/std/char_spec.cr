require "spec"
require "unicode"
require "spec/helpers/iterate"
require "spec/helpers/string"

describe "Char" do
  describe "#upcase" do
    it { 'a'.upcase.should eq('A') }
    it { '1'.upcase.should eq('1') }
    it { assert_iterates_yielding ['F', 'F', 'L'], 'ﬄ'.upcase }
  end

  describe "#downcase" do
    it { 'A'.downcase.should eq('a') }
    it { '1'.downcase.should eq('1') }
    it { assert_iterates_yielding ['i', '\u{0307}'], 'İ'.downcase }
    it { assert_iterates_yielding ['s', 's'], 'ß'.downcase(Unicode::CaseOptions::Fold) }
    it { 'Ń'.downcase(Unicode::CaseOptions::Fold).should eq('ń') }
    it { 'ꭰ'.downcase(Unicode::CaseOptions::Fold).should eq('Ꭰ') }
    it { 'Ꭰ'.downcase(Unicode::CaseOptions::Fold).should eq('Ꭰ') }
  end

  describe "#titlecase" do
    it { 'a'.titlecase.should eq('A') }
    it { '1'.titlecase.should eq('1') }
    it { '\u{10D0}'.titlecase.should eq('\u{10D0}') } # GEORGIAN LETTER AN
    it { assert_iterates_yielding ['F', 'f', 'l'], 'ﬄ'.titlecase }
  end

  it "#succ" do
    'a'.succ.should eq('b')
    'あ'.succ.should eq('ぃ')

    '\uD7FF'.succ.should eq '\uE000'

    expect_raises OverflowError, "Out of Char range" do
      Char::MAX.succ
    end
  end

  it "#pred" do
    'b'.pred.should eq('a')
    'ぃ'.pred.should eq('あ')

    '\uE000'.pred.should eq '\uD7FF'

    expect_raises OverflowError, "Out of Char range" do
      Char::ZERO.pred
    end
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

  describe "#titlecase?" do
    it { 'ǲ'.titlecase?.should be_true }
    it { 'ᾈ'.titlecase?.should be_true }
    it { 'A'.titlecase?.should be_false }
    it { 'a'.titlecase?.should be_false }
  end

  describe "ascii_letter?" do
    it { 'a'.ascii_letter?.should be_true }
    it { 'A'.ascii_letter?.should be_true }
    it { '1'.ascii_letter?.should be_false }
    it { ' '.ascii_letter?.should be_false }
  end

  it "#letter?" do
    'A'.letter?.should be_true # Unicode General Category Lu
    'a'.letter?.should be_true # Unicode General Category Ll
    'ǅ'.letter?.should be_true # Unicode General Category Lt
    'ʰ'.letter?.should be_true # Unicode General Category Lm
    'か'.letter?.should be_true # Unicode General Category Lo

    'ः'.letter?.should be_false  # Unicode General Category M
    '1'.letter?.should be_false  # Unicode General Category Nd
    'Ⅰ'.letter?.should be_false  # Unicode General Category Nl
    '_'.letter?.should be_false  # Unicode General Category P
    '$'.letter?.should be_false  # Unicode General Category S
    ' '.letter?.should be_false  # Unicode General Category Z
    '\n'.letter?.should be_false # Unicode General Category C
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

  it "#dump" do
    assert_prints 'a'.dump, %('a')
    assert_prints '\\'.dump, %('\\\\')
    assert_prints '\0'.dump, %('\\0')
    assert_prints '\u0001'.dump, %('\\u0001')
    assert_prints ' '.dump, %(' ')
    assert_prints '\a'.dump, %('\\a')
    assert_prints '\b'.dump, %('\\b')
    assert_prints '\e'.dump, %('\\e')
    assert_prints '\f'.dump, %('\\f')
    assert_prints '\n'.dump, %('\\n')
    assert_prints '\r'.dump, %('\\r')
    assert_prints '\t'.dump, %('\\t')
    assert_prints '\v'.dump, %('\\v')
    assert_prints '\f'.dump, %('\\f')
    assert_prints 'á'.dump, %('\\u00E1')
    assert_prints '\uF8FF'.dump, %('\\uF8FF')
    assert_prints '\u202A'.dump, %('\\u202A')
    assert_prints '\u{81}'.dump, %('\\u0081')
    assert_prints '\u{110BD}'.dump, %('\\u{110BD}')
    assert_prints '\u{1F48E}'.dump, %('\\u{1F48E}')
    assert_prints '\u00AD'.dump, %('\\u00AD')
  end

  it "#inspect" do
    assert_prints 'a'.inspect, %('a')
    assert_prints '\\'.inspect, %('\\\\')
    assert_prints '\0'.inspect, %('\\0')
    assert_prints '\u0001'.inspect, %('\\u0001')
    assert_prints ' '.inspect, %(' ')
    assert_prints '\a'.inspect, %('\\a')
    assert_prints '\b'.inspect, %('\\b')
    assert_prints '\e'.inspect, %('\\e')
    assert_prints '\f'.inspect, %('\\f')
    assert_prints '\n'.inspect, %('\\n')
    assert_prints '\r'.inspect, %('\\r')
    assert_prints '\t'.inspect, %('\\t')
    assert_prints '\v'.inspect, %('\\v')
    assert_prints '\f'.inspect, %('\\f')
    assert_prints 'á'.inspect, %('á')
    assert_prints '\uF8FF'.inspect, %('\\uF8FF')
    assert_prints '\u202A'.inspect, %('\\u202A')
    assert_prints '\u{81}'.inspect, %('\\u0081')
    assert_prints '\u{110BD}'.inspect, %('\\u{110BD}')
    assert_prints '\u{1F48E}'.inspect, %('\u{1F48E}')
    assert_prints '\u00AD'.inspect, %('\\u00AD')
  end

  it "#unicode_escape" do
    assert_prints 'a'.unicode_escape, %(\\u0061)
    assert_prints '\\'.unicode_escape, %(\\u005C)
    assert_prints '\0'.unicode_escape, %(\\u0000)
    assert_prints '\u0001'.unicode_escape, %(\\u0001)
    assert_prints ' '.unicode_escape, %(\\u0020)
    assert_prints '\a'.unicode_escape, %(\\u0007)
    assert_prints '\b'.unicode_escape, %(\\u0008)
    assert_prints '\e'.unicode_escape, %(\\u001B)
    assert_prints '\f'.unicode_escape, %(\\u000C)
    assert_prints '\n'.unicode_escape, %(\\u000A)
    assert_prints '\r'.unicode_escape, %(\\u000D)
    assert_prints '\t'.unicode_escape, %(\\u0009)
    assert_prints '\v'.unicode_escape, %(\\u000B)
    assert_prints '\f'.unicode_escape, %(\\u000C)
    assert_prints 'á'.unicode_escape, %(\\u00E1)
    assert_prints '\uF8FF'.unicode_escape, %(\\uF8FF)
    assert_prints '\u202A'.unicode_escape, %(\\u202A)
    assert_prints '\u{81}'.unicode_escape, %(\\u0081)
    assert_prints '\u{110BD}'.unicode_escape, %(\\u{110BD})
    assert_prints '\u00AD'.unicode_escape, %(\\u00AD)
  end

  it "escapes" do
    '\a'.ord.should eq(7)
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
    '1'.to_i128.should eq(1i128)

    expect_raises(ArgumentError) { 'a'.to_i8 }
    expect_raises(ArgumentError) { 'a'.to_i16 }
    expect_raises(ArgumentError) { 'a'.to_i32 }
    expect_raises(ArgumentError) { 'a'.to_i64 }
    expect_raises(ArgumentError) { 'a'.to_i128 }

    'a'.to_i8?.should be_nil
    'a'.to_i16?.should be_nil
    'a'.to_i32?.should be_nil
    'a'.to_i64?.should be_nil
    'a'.to_i128?.should be_nil

    '1'.to_u8.should eq(1u8)
    '1'.to_u16.should eq(1u16)
    '1'.to_u32.should eq(1u32)
    '1'.to_u64.should eq(1u64)
    '1'.to_u128.should eq(1u128)

    expect_raises(ArgumentError) { 'a'.to_u8 }
    expect_raises(ArgumentError) { 'a'.to_u16 }
    expect_raises(ArgumentError) { 'a'.to_u32 }
    expect_raises(ArgumentError) { 'a'.to_u64 }
    expect_raises(ArgumentError) { 'a'.to_u128 }

    'a'.to_u8?.should be_nil
    'a'.to_u16?.should be_nil
    'a'.to_u32?.should be_nil
    'a'.to_u64?.should be_nil
    'a'.to_u128?.should be_nil
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

  describe "#step" do
    it_iterates "basic", ['a', 'b', 'c', 'd', 'e'], 'a'.step(to: 'e')
    it_iterates "basic by", ['a', 'c', 'e'], 'a'.step(to: 'e', by: 2)
  end

  describe "+" do
    it "does for both ascii" do
      str = 'f' + "oo"
      str.@length.should eq(3) # Check that it was precomputed
      str.should eq("foo")
    end

    it "does for both unicode" do
      str = '青' + "旅路"
      str.@length.should eq(3) # Check that it was precomputed
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
      expect_raises(ArgumentError, "Invalid range c-a") do
        'a'.in_set?("c-a")
      end
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
    '1'.number?.should be_true
    '٠'.number?.should be_true
    '٢'.number?.should be_true
    'a'.number?.should be_false
  end

  it "#ascii_control?" do
    'ù'.ascii_control?.should be_false
    'a'.ascii_control?.should be_false
    '\u0019'.ascii_control?.should be_true
    '\u007F'.ascii_control?.should be_true
    '\u0080'.ascii_control?.should be_false
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

  it "#printable?" do
    ' '.printable?.should be_true
    'a'.printable?.should be_true
    '酒'.printable?.should be_true
    '\n'.printable?.should be_false
    '\e'.printable?.should be_false
    '\uF8FF'.printable?.should be_false
  end

  describe "clone" do
    it { 'a'.clone.should eq('a') }
  end
end
