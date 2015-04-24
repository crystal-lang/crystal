require "spec"

describe "Char" do
  describe "upcase" do
    assert { expect('a'.upcase).to eq('A') }
    assert { expect('1'.upcase).to eq('1') }
  end

  describe "downcase" do
    assert { expect('A'.downcase).to eq('a') }
    assert { expect('1'.downcase).to eq('1') }
  end

  describe "whitespace?" do
    [' ', '\t', '\n', '\v', '\f', '\r'].each do |char|
      assert { expect(char.whitespace?).to be_true }
    end
  end

  it "dumps" do
    expect('a'.dump).to eq("'a'")
    expect('\\'.dump).to eq("'\\\\'")
    expect('\e'.dump).to eq("'\\e'")
    expect('\f'.dump).to eq("'\\f'")
    expect('\n'.dump).to eq("'\\n'")
    expect('\r'.dump).to eq("'\\r'")
    expect('\t'.dump).to eq("'\\t'")
    expect('\v'.dump).to eq("'\\v'")
    expect('á'.dump).to eq("'\\u{E1}'")
    expect('\u{81}'.dump).to eq("'\\u{81}'")
  end

  it "inspects" do
    expect('a'.inspect).to eq("'a'")
    expect('\\'.inspect).to eq("'\\\\'")
    expect('\e'.inspect).to eq("'\\e'")
    expect('\f'.inspect).to eq("'\\f'")
    expect('\n'.inspect).to eq("'\\n'")
    expect('\r'.inspect).to eq("'\\r'")
    expect('\t'.inspect).to eq("'\\t'")
    expect('\v'.inspect).to eq("'\\v'")
    expect('á'.inspect).to eq("'á'")
    expect('\u{81}'.inspect).to eq("'\\u{81}'")
  end

  it "escapes" do
    expect('\b'.ord).to eq(8)
    expect('\t'.ord).to eq(9)
    expect('\n'.ord).to eq(10)
    expect('\v'.ord).to eq(11)
    expect('\f'.ord).to eq(12)
    expect('\r'.ord).to eq(13)
    expect('\e'.ord).to eq(27)
    expect('\''.ord).to eq(39)
    expect('\\'.ord).to eq(92)
  end

  it "escapes with octal" do
    expect('\0'.ord).to eq(0)
    expect('\3'.ord).to eq(3)
    expect('\23'.ord).to eq((2 * 8) + 3)
    expect('\123'.ord).to eq((1 * 8 * 8) + (2 * 8) + 3)
    expect('\033'.ord).to eq((3 * 8) + 3)
  end

  it "escapes with unicode" do
    expect('\u{12}'.ord).to eq(1 * 16 + 2)
    expect('\u{A}'.ord).to eq(10)
    expect('\u{AB}'.ord).to eq(10 * 16 + 11)
  end

  it "does to_i without a base" do
    ('0'..'9').each_with_index do |c, i|
      expect(c.to_i).to eq(i)
    end
    expect('a'.to_i).to eq(0)
  end

  it "does to_i with 16 base" do
    ('0'..'9').each_with_index do |c, i|
      expect(c.to_i(16)).to eq(i)
    end
    ('a'..'f').each_with_index do |c, i|
      expect(c.to_i(16)).to eq(10 + i)
    end
    ('A'..'F').each_with_index do |c, i|
      expect(c.to_i(16)).to eq(10 + i)
    end
    expect('Z'.to_i(16)).to eq(0)
    expect('Z'.to_i(16, or_else: -1)).to eq(-1)
  end

  it "does ord for multibyte char" do
    expect('日'.ord).to eq(26085)
  end

  it "does to_s for single-byte char" do
    expect('a'.to_s).to eq("a")
  end

  it "does to_s for multibyte char" do
    expect('日'.to_s).to eq("日")
  end

  describe "index" do
    assert { expect("foo".index('o')).to eq(1) }
    assert { expect("foo".index('x')).to be_nil }
  end

  it "does <=>" do
    expect(('a' <=> 'b')).to be < 0
    expect(('a' <=> 'a')).to eq(0)
    expect(('b' <=> 'a')).to be > 0
  end

  describe "in_set?" do
    assert { expect('a'.in_set?("a")).to be_true }
    assert { expect('a'.in_set?("b")).to be_false }
    assert { expect('a'.in_set?("a-c")).to be_true }
    assert { expect('b'.in_set?("a-c")).to be_true }
    assert { expect('c'.in_set?("a-c")).to be_true }
    assert { expect('c'.in_set?("a-bc")).to be_true }
    assert { expect('b'.in_set?("a-bc")).to be_true }
    assert { expect('d'.in_set?("a-c")).to be_false }
    assert { expect('b'.in_set?("^a-c")).to be_false }
    assert { expect('d'.in_set?("^a-c")).to be_true }
    assert { expect('a'.in_set?("ab-c")).to be_true }
    assert { expect('a'.in_set?("\\^ab-c")).to be_true }
    assert { expect('^'.in_set?("\\^ab-c")).to be_true }
    assert { expect('^'.in_set?("a^b-c")).to be_true }
    assert { expect('^'.in_set?("ab-c^")).to be_true }
    assert { expect('^'.in_set?("a0-^")).to be_true }
    assert { expect('^'.in_set?("^-c")).to be_true }
    assert { expect('^'.in_set?("a^-c")).to be_true }
    assert { expect('\\'.in_set?("ab-c\\")).to be_true }
    assert { expect('\\'.in_set?("a\\b-c")).to be_false }
    assert { expect('\\'.in_set?("a0-\\c")).to be_true }
    assert { expect('\\'.in_set?("a\\-c")).to be_false }
    assert { expect('-'.in_set?("a-c")).to be_false }
    assert { expect('-'.in_set?("a-c")).to be_false }
    assert { expect('-'.in_set?("a\\-c")).to be_true }
    assert { expect('-'.in_set?("-c")).to be_true }
    assert { expect('-'.in_set?("a-")).to be_true }
    assert { expect('-'.in_set?("^-c")).to be_false }
    assert { expect('-'.in_set?("^\\-c")).to be_false }
    assert { expect('b'.in_set?("^\\-c")).to be_true }
    assert { expect('-'.in_set?("a^-c")).to be_false }
    assert { expect('a'.in_set?("a", "ab")).to be_true }
    assert { expect('a'.in_set?("a", "^b")).to be_true }
    assert { expect('a'.in_set?("a", "b")).to be_false }
    assert { expect('a'.in_set?("ab", "ac", "ad")).to be_true }

    it "rejects invalid ranges" do
      expect_raises do
        'a'.in_set?("c-a")
      end
    end
  end

  it "raises on codepoint bigger than 0x10ffff when doing each_byte" do
    expect_raises do
      (0x10ffff + 1).chr.each_byte { |b| }
    end
  end

  it "does bytes" do
    expect('\u{FF}'.bytes).to eq([195, 191])
  end
end
