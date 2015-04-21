require "spec"

describe "String" do
  describe "[]" do
    it "gets with positive index" do
      c = "hello!"[1]
      expect(c).to be_a(Char)
      expect(c).to eq('e')
    end

    it "gets with negative index" do
      expect("hello!"[-1]).to eq('!')
    end

    it "gets with inclusive range" do
      expect("hello!"[1 .. 4]).to eq("ello")
    end

    it "gets with inclusive range with negative indices" do
      expect("hello!"[-5 .. -2]).to eq("ello")
    end

    it "gets with exclusive range" do
      expect("hello!"[1 ... 4]).to eq("ell")
    end

    it "gets with start and count" do
      expect("hello"[1, 3]).to eq("ell")
    end

    it "gets with exclusive range with unicode" do
      expect("há日本語"[1 .. 3]).to eq("á日本")
    end

    it "gets with exclusive with start and count" do
      expect("há日本語"[1, 3]).to eq("á日本")
    end

    it "gets with exclusive with start and count to end" do
      expect("há日本語"[1, 4]).to eq("á日本語")
    end

    it "gets with single char" do
      expect(";"[0 .. -2]).to eq("")
    end

    describe "with a regex" do
      assert { expect("FooBar"[/o+/]).to eq "oo" }
      assert { expect("FooBar"[/([A-Z])/, 1]).to eq "F" }
      assert { expect("FooBar"[/x/]?).to be_nil }
      assert { expect("FooBar"[/x/, 1]?).to be_nil }
      assert { expect("FooBar"[/(x)/, 1]?).to be_nil }
      assert { expect("FooBar"[/o(o)/, 2]?).to be_nil }
      assert { expect("FooBar"[/o(?<this>o)/, "this"]).to eq "o" }
      assert { expect("FooBar"[/(?<this>x)/, "that"]?).to be_nil }
    end

    it "gets with a string" do
      expect("FooBar"["Bar"]).to eq "Bar"
      expect_raises { "FooBar"["Baz"] }
      expect("FooBar"["Bar"]?).to eq "Bar"
      expect("FooBar"["Baz"]?).to be_nil
    end

    it "gets with index and []?" do
      expect("hello"[1]?).to eq('e')
      expect("hello"[5]?).to be_nil
      expect("hello"[-1]?).to eq('o')
      expect("hello"[-6]?).to be_nil
    end
  end

  describe "byte_slice" do
    it "gets byte_slice" do
      expect("hello".byte_slice(1, 3)).to eq("ell")
    end

    it "gets byte_slice with negative count" do
      expect("hello".byte_slice(1, -10)).to eq("")
    end

    it "gets byte_slice with start out of bounds" do
      expect("hello".byte_slice(10, 3)).to eq("")
    end

    it "gets byte_slice with large count" do
      expect("hello".byte_slice(1, 10)).to eq("ello")
    end

    it "gets byte_slice with negative index" do
      expect("hello".byte_slice(-2, 3)).to eq("lo")
    end
  end

  it "does to_i" do
    expect("1234".to_i).to eq(1234)
  end

  it "does to_i with base" do
    expect("12ab".to_i(16)).to eq(4779)
  end

  it "raises on to_i(1)" do
    expect_raises { "12ab".to_i(1) }
  end

  it "raises on to_i(37)" do
    expect_raises { "12ab".to_i(37) }
  end

  it "does to_i32" do
    expect("1234".to_i32).to eq(1234)
  end

  it "does to_i64" do
    expect("1234123412341234".to_i64).to eq(1234123412341234_i64)
  end

  it "does to_u64" do
    expect("9223372036854775808".to_u64).to eq(9223372036854775808_u64)
  end

  it "does to_f" do
    expect("1234.56".to_f).to eq(1234.56_f64)
  end

  it "does to_f32" do
    expect("1234.56".to_f32).to eq(1234.56_f32)
  end

  it "does to_f64" do
    expect("1234.56".to_f64).to eq(1234.56_f64)
  end

  it "compares strings: different length" do
    expect("foo").to_not eq("fo")
  end

  it "compares strings: same object" do
    f = "foo"
    expect(f).to eq(f)
  end

  it "compares strings: same length, same string" do
    expect("foo").to eq("fo" + "o")
  end

  it "compares strings: same length, different string" do
    expect("foo").to_not eq("bar")
  end

  it "interpolates string" do
    foo = "<foo>"
    bar = 123
    expect("foo #{bar}").to eq("foo 123")
    expect("foo #{ bar}").to eq("foo 123")
    expect("#{foo} bar").to eq("<foo> bar")
  end

  it "multiplies" do
    str = "foo"
    expect((str * 0)).to eq("")
    expect((str * 3)).to eq("foofoofoo")
  end

  it "multiplies with length one" do
    str = "f"
    expect((str * 0)).to eq("")
    expect((str * 10)).to eq("ffffffffff")
  end

  describe "downcase" do
    assert { expect("HELLO!".downcase).to eq("hello!") }
    assert { expect("HELLO MAN!".downcase).to eq("hello man!") }
  end

  describe "upcase" do
    assert { expect("hello!".upcase).to eq("HELLO!") }
    assert { expect("hello man!".upcase).to eq("HELLO MAN!") }
  end

  describe "capitalize" do
    assert { expect("HELLO!".capitalize).to eq("Hello!") }
    assert { expect("HELLO MAN!".capitalize).to eq("Hello man!") }
    assert { expect("".capitalize).to eq("") }
  end

  describe "chomp" do
    assert { expect("hello\n".chomp).to eq("hello") }
    assert { expect("hello\r".chomp).to eq("hello") }
    assert { expect("hello\r\n".chomp).to eq("hello") }
    assert { expect("hello".chomp).to eq("hello") }
    assert { expect("hello".chomp).to eq("hello") }
    assert { expect("かたな\n".chomp).to eq("かたな") }
    assert { expect("かたな\r".chomp).to eq("かたな") }
    assert { expect("かたな\r\n".chomp).to eq("かたな") }
    assert { expect("hello\n\n".chomp).to eq("hello\n") }
    assert { expect("hello\r\n\n".chomp).to eq("hello\r\n") }
  end

  describe "strip" do
    assert { expect("  hello  \n\t\f\v\r".strip).to eq("hello") }
    assert { expect("hello".strip).to eq("hello") }
    assert { expect("かたな \n\f\v".strip).to eq("かたな") }
    assert { expect("  \n\t かたな \n\f\v".strip).to eq("かたな") }
    assert { expect("  \n\t かたな".strip).to eq("かたな") }
    assert { expect("かたな".strip).to eq("かたな") }
  end

  describe "rstrip" do
    assert { expect("  hello  ".rstrip).to eq("  hello") }
    assert { expect("hello".rstrip).to eq("hello") }
    assert { expect("  かたな \n\f\v".rstrip).to eq("  かたな") }
    assert { expect("かたな".rstrip).to eq("かたな") }
  end

  describe "lstrip" do
    assert { expect("  hello  ".lstrip).to eq("hello  ") }
    assert { expect("hello".lstrip).to eq("hello") }
    assert { expect("  \n\v かたな  ".lstrip).to eq("かたな  ") }
    assert { expect("  かたな".lstrip).to eq("かたな") }
  end

  describe "empty?" do
    assert { expect("a".empty?).to be_false }
    assert { expect("".empty?).to be_true }
  end

  describe "index" do
    describe "by char" do
      assert { expect("foo".index('o')).to eq(1) }
      assert { expect("foo".index('g')).to be_nil }
      assert { expect("bar".index('r')).to eq(2) }
      assert { expect("日本語".index('本')).to eq(1) }
      assert { expect("bar".index('あ')).to be_nil }

      describe "with offset" do
        assert { expect("foobarbaz".index('a', 5)).to eq(7) }
        assert { expect("foobarbaz".index('a', -4)).to eq(7) }
        assert { expect("foo".index('g', 1)).to be_nil }
        assert { expect("foo".index('g', -20)).to be_nil }
        assert { expect("日本語日本語".index('本', 2)).to eq(4) }
      end
    end

    describe "by string" do
      assert { expect("foo bar".index("o b")).to eq(2) }
      assert { expect("foo".index("fg")).to be_nil }
      assert { expect("foo".index("")).to eq(0) }
      assert { expect("foo".index("foo")).to eq(0) }
      assert { expect("日本語日本語".index("本語")).to eq(1) }

      describe "with offset" do
        assert { expect("foobarbaz".index("ba", 4)).to eq(6) }
        assert { expect("foobarbaz".index("ba", -5)).to eq(6) }
        assert { expect("foo".index("ba", 1)).to be_nil }
        assert { expect("foo".index("ba", -20)).to be_nil }
        assert { expect("日本語日本語".index("本語", 2)).to eq(4) }
      end
    end
  end

  describe "rindex" do
    describe "by char" do
      assert { expect("foobar".rindex('a')).to eq(4) }
      assert { expect("foobar".rindex('g')).to be_nil }
      assert { expect("日本語日本語".rindex('本')).to eq(4) }

      describe "with offset" do
        assert { expect("faobar".rindex('a', 3)).to eq(1) }
        assert { expect("faobarbaz".rindex('a', -3)).to eq(4) }
        assert { expect("日本語日本語".rindex('本', 3)).to eq(1) }
      end
    end

    describe "by string" do
      assert { expect("foo baro baz".rindex("o b")).to eq(7) }
      assert { expect("foo baro baz".rindex("fg")).to be_nil }
      assert { expect("日本語日本語".rindex("日本")).to eq(3) }

      describe "with offset" do
        assert { expect("foo baro baz".rindex("o b", 6)).to eq(2) }
        assert { expect("foo baro baz".rindex("fg")).to be_nil }
        assert { expect("日本語日本語".rindex("日本", 2)).to eq(0) }
      end
    end
  end

  describe "byte_index" do
    assert { expect("foo".byte_index('o'.ord)).to eq(1) }
    assert { expect("foo bar booz".byte_index('o'.ord, 3)).to eq(9) }
    assert { expect("foo".byte_index('a'.ord)).to be_nil }

    it "gets byte index of string" do
      expect("hello world".byte_index("lo")).to eq(3)
    end
  end

  describe "includes?" do
    describe "by char" do
      assert { expect("foo".includes?('o')).to be_true }
      assert { expect("foo".includes?('g')).to be_false }
    end

    describe "by string" do
      assert { expect("foo bar".includes?("o b")).to be_true }
      assert { expect("foo".includes?("fg")).to be_false }
      assert { expect("foo".includes?("")).to be_true }
    end
  end

  describe "split" do
    describe "by char" do
      assert { expect("foo,bar,,baz,".split(',')).to eq(["foo", "bar", "", "baz"]) }
      assert { expect("foo,bar,,baz".split(',')).to eq(["foo", "bar", "", "baz"]) }
      assert { expect("foo".split(',')).to eq(["foo"]) }
      assert { expect("foo".split(' ')).to eq(["foo"]) }
      assert { expect("   foo".split(' ')).to eq(["foo"]) }
      assert { expect("foo   ".split(' ')).to eq(["foo"]) }
      assert { expect("   foo  bar".split(' ')).to eq(["foo", "bar"]) }
      assert { expect("   foo   bar\n\t  baz   ".split(' ')).to eq(["foo", "bar", "baz"]) }
      assert { expect("   foo   bar\n\t  baz   ".split).to eq(["foo", "bar", "baz"]) }
      assert { expect("   foo   bar\n\t  baz   ".split(2)).to eq(["foo", "bar\n\t  baz   "]) }
      assert { expect("   foo   bar\n\t  baz   ".split(" ")).to eq(["foo", "bar", "baz"]) }
      assert { expect("foo,bar,baz,qux".split(',', 1)).to eq(["foo,bar,baz,qux"]) }
      assert { expect("foo,bar,baz,qux".split(',', 3)).to eq(["foo", "bar", "baz,qux"]) }
      assert { expect("foo,bar,baz,qux".split(',', 30)).to eq(["foo", "bar", "baz", "qux"]) }
      assert { expect("foo bar baz qux".split(' ', 1)).to eq(["foo bar baz qux"]) }
      assert { expect("foo bar baz qux".split(' ', 3)).to eq(["foo", "bar", "baz qux"]) }
      assert { expect("foo bar baz qux".split(' ', 30)).to eq(["foo", "bar", "baz", "qux"]) }
      assert { expect("日本語 \n\t 日本 \n\n 語".split).to eq(["日本語", "日本", "語"]) }
      assert { expect("日本ん語日本ん語".split('ん')).to eq(["日本", "語日本", "語"]) }
    end

    describe "by string" do
      assert { expect("foo:-bar:-:-baz:-".split(":-")).to eq(["foo", "bar", "", "baz"]) }
      assert { expect("foo:-bar:-:-baz".split(":-")).to eq(["foo", "bar", "", "baz"]) }
      assert { expect("foo".split(":-")).to eq(["foo"]) }
      assert { expect("foo".split("")).to eq(["f", "o", "o"]) }
      assert { expect("日本さん語日本さん語".split("さん")).to eq(["日本", "語日本", "語"]) }
      assert { expect("foo,bar,baz,qux".split(",", 1)).to eq(["foo,bar,baz,qux"]) }
      assert { expect("foo,bar,baz,qux".split(",", 3)).to eq(["foo", "bar", "baz,qux"]) }
      assert { expect("foo,bar,baz,qux".split(",", 30)).to eq(["foo", "bar", "baz", "qux"]) }
      assert { expect("a b c".split(" ", 2)).to eq(["a", "b c"]) }
    end

    describe "by regex" do
      assert { expect("foo\n\tbar\n\t\n\tbaz".split(/\n\t/)).to eq(["foo", "bar", "", "baz"]) }
      assert { expect("foo\n\tbar\n\t\n\tbaz".split(/(\n\t)+/)).to eq(["foo", "bar", "baz"]) }
      assert { expect("foo,bar".split(/,/, 1)).to eq(["foo,bar"]) }
      assert { expect("foo,bar,baz,qux".split(/,/, 1)).to eq(["foo,bar,baz,qux"]) }
      assert { expect("foo,bar,baz,qux".split(/,/, 3)).to eq(["foo", "bar", "baz,qux"]) }
      assert { expect("foo,bar,baz,qux".split(/,/, 30)).to eq(["foo", "bar", "baz", "qux"]) }
      assert { expect("a b c".split(Regex.new(" "), 2)).to eq(["a", "b c"]) }
      assert { expect("日本ん語日本ん語".split(/ん/)).to eq(["日本", "語日本", "語"]) }
      assert { expect("hello world".split(/\b/)).to eq(["hello", " ", "world"]) }
      assert { expect("abc".split(//)).to eq(["a", "b", "c"]) }
      assert { expect("hello".split(/\w+/).empty?).to be_true }
      assert { expect("foo".split(/o/)).to eq(["f"]) }

      it "works with complex regex" do
        r = %r([\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"|;.*|[^\s\[\]{}('"`,;)]*))
        expect("hello".split(r)).to eq(["", "hello"])
      end
    end
  end

  describe "starts_with?" do
    assert { expect("foobar".starts_with?("foo")).to be_true }
    assert { expect("foobar".starts_with?("")).to be_true }
    assert { expect("foobar".starts_with?("foobarbaz")).to be_false }
    assert { expect("foobar".starts_with?("foox")).to be_false }
    assert { expect("foobar".starts_with?('f')).to be_true }
    assert { expect("foobar".starts_with?('g')).to be_false }
    assert { expect("よし".starts_with?('よ')).to be_true }
    assert { expect("よし!".starts_with?("よし")).to be_true }
  end

  describe "ends_with?" do
    assert { expect("foobar".ends_with?("bar")).to be_true }
    assert { expect("foobar".ends_with?("")).to be_true }
    assert { expect("foobar".ends_with?("foobarbaz")).to be_false }
    assert { expect("foobar".ends_with?("xbar")).to be_false }
    assert { expect("foobar".ends_with?('r')).to be_true }
    assert { expect("foobar".ends_with?('x')).to be_false }
    assert { expect("よし".ends_with?('し')).to be_true }
    assert { expect("よし".ends_with?('な')).to be_false }
  end

  describe "=~" do
    it "matches with group" do
      "foobar" =~ /(o+)ba(r?)/
      expect($1).to eq("oo")
      expect($2).to eq("r")
    end
  end

  describe "delete" do
    assert { expect("foobar".delete {|char| char == 'o' }).to eq("fbar") }
    assert { expect("hello world".delete("lo")).to eq("he wrd") }
    assert { expect("hello world".delete("lo", "o")).to eq("hell wrld") }
    assert { expect("hello world".delete("hello", "^l")).to eq("ll wrld") }
    assert { expect("hello world".delete("ej-m")).to eq("ho word") }
    assert { expect("hello^world".delete("\\^aeiou")).to eq("hllwrld") }
    assert { expect("hello-world".delete("a\\-eo")).to eq("hllwrld") }
    assert { expect("hello world\\r\\n".delete("\\")).to eq("hello worldrn") }
    assert { expect("hello world\\r\\n".delete("\\A")).to eq("hello world\\r\\n") }
    assert { expect("hello world\\r\\n".delete("X-\\w")).to eq("hello orldrn") }

    it "deletes one char" do
      deleted = "foobar".delete('o')
      expect(deleted.bytesize).to eq(4)
      expect(deleted).to eq("fbar")

      deleted = "foobar".delete('x')
      expect(deleted.bytesize).to eq(6)
      expect(deleted).to eq("foobar")
    end
  end

  it "reverses string" do
    reversed = "foobar".reverse
    expect(reversed.bytesize).to eq(6)
    expect(reversed).to eq("raboof")
  end

  it "reverses utf-8 string" do
    reversed = "こんいちは".reverse
    expect(reversed.bytesize).to eq(15)
    expect(reversed.length).to eq(5)
    expect(reversed).to eq("はちいんこ")
  end

  it "gsubs char with char" do
    replaced = "foobar".gsub('o', 'e')
    expect(replaced.bytesize).to eq(6)
    expect(replaced).to eq("feebar")
  end

  it "gsubs char with string" do
    replaced = "foobar".gsub('o', "ex")
    expect(replaced.bytesize).to eq(8)
    expect(replaced).to eq("fexexbar")
  end

  it "gsubs char with string depending on the char" do
    replaced = "foobar".gsub do |char|
      case char
      when 'f'
        "some"
      when 'o'
        "thing"
      when 'a'
        "ex"
      else
        char
      end
    end
    expect(replaced.bytesize).to eq(18)
    expect(replaced).to eq("somethingthingbexr")
  end

  it "gsubs with regex and block" do
    actual = "foo booor booooz".gsub(/o+/) do |str|
      "#{str}#{str.length}"
    end
    expect(actual).to eq("foo2 booo3r boooo4z")
  end

  it "gsubs with regex and block with group" do
    actual = "foo booor booooz".gsub(/(o+).*?(o+)/) do |str, match|
      "#{match[1].length}#{match[2].length}"
    end
    expect(actual).to eq("f23r b31z")
  end

  it "gsubs with regex and string" do
    expect("foo boor booooz".gsub(/o+/, "a")).to eq("fa bar baz")
  end

  it "gsubs with regex and string, returns self if no match" do
    str = "hello"
    expect(str.gsub(/a/, "b")).to be(str)
  end

  it "gsubs with regex and string (utf-8)" do
    expect("fここ bここr bここここz".gsub(/こ+/, "そこ")).to eq("fそこ bそこr bそこz")
  end

  it "gsubs with string and string" do
    expect("foo boor booooz".gsub("oo", "a")).to eq("fa bar baaz")
  end

  it "gsubs with string and string return self if no match" do
    str = "hello"
    expect(str.gsub("a", "b")).to be(str)
  end

  it "gsubs with string and string (utf-8)" do
    expect("fここ bここr bここここz".gsub("ここ", "そこ")).to eq("fそこ bそこr bそこそこz")
  end

  it "gsubs with string and block" do
    i = 0
    result = "foo boo".gsub("oo") do |value|
      expect(value).to eq("oo")
      i += 1
      i == 1 ? "a" : "e"
    end
    expect(result).to eq("fa be")
  end

  it "gsubs with char hash" do
    str = "hello"
    expect(str.gsub({'e' => 'a', 'l' => 'd'})).to eq("haddo")
  end

  it "gsubs with regex and hash" do
    str = "hello"
    expect(str.gsub(/(he|l|o)/, {"he": "ha", "l": "la"})).to eq("halala")
  end

  it "dumps" do
    expect("a".dump).to eq("\"a\"")
    expect("\\".dump).to eq("\"\\\\\"")
    expect("\"".dump).to eq("\"\\\"\"")
    expect("\b".dump).to eq("\"\\b\"")
    expect("\e".dump).to eq("\"\\e\"")
    expect("\f".dump).to eq("\"\\f\"")
    expect("\n".dump).to eq("\"\\n\"")
    expect("\r".dump).to eq("\"\\r\"")
    expect("\t".dump).to eq("\"\\t\"")
    expect("\v".dump).to eq("\"\\v\"")
    expect("\#{".dump).to eq("\"\\\#{\"")
    expect("á".dump).to eq("\"\\u{E1}\"")
    expect("\u{81}".dump).to eq("\"\\u{81}\"")
  end

  it "inspects" do
    expect("a".inspect).to eq("\"a\"")
    expect("\\".inspect).to eq("\"\\\\\"")
    expect("\"".inspect).to eq("\"\\\"\"")
    expect("\b".inspect).to eq("\"\\b\"")
    expect("\e".inspect).to eq("\"\\e\"")
    expect("\f".inspect).to eq("\"\\f\"")
    expect("\n".inspect).to eq("\"\\n\"")
    expect("\r".inspect).to eq("\"\\r\"")
    expect("\t".inspect).to eq("\"\\t\"")
    expect("\v".inspect).to eq("\"\\v\"")
    expect("\#{".inspect).to eq("\"\\\#{\"")
    expect("á".inspect).to eq("\"á\"")
    expect("\u{81}".inspect).to eq("\"\\u{81}\"")
  end

  it "does *" do
    str = "foo" * 10
    expect(str.bytesize).to eq(30)
    expect(str).to eq("foofoofoofoofoofoofoofoofoofoo")
  end

  describe "+" do
    it "does for both ascii" do
      str = "foo" + "bar"
      expect(str.bytesize).to eq(6)
      expect(str.@length).to eq(6)
      expect(str).to eq("foobar")
    end

    it "does for both unicode" do
      str = "青い" + "旅路"
      expect(str.@length).to eq(4)
      expect(str).to eq("青い旅路")
    end

    it "does with ascii char" do
      str = "foo"
      str2 = str + '/'
      expect(str2).to eq("foo/")
      expect(str2.bytesize).to eq(4)
      expect(str2.length).to eq(4)
    end

    it "does with unicode char" do
      str = "fooba"
      str2 = str + 'る'
      expect(str2).to eq("foobaる")
      expect(str2.bytesize).to eq(8)
      expect(str2.length).to eq(6)
    end
  end

  it "does %" do
    expect(("foo" % 1)).to        eq("foo")
    expect(("foo %d" % 1)).to     eq("foo 1")
    expect(("%d" % 123)).to       eq("123")
    expect(("%+d" % 123)).to      eq("+123")
    expect(("%+d" % -123)).to     eq("-123")
    expect(("% d" % 123)).to      eq(" 123")
    expect(("%20d" % 123)).to     eq("                 123")
    expect(("%+20d" % 123)).to    eq("                +123")
    expect(("%+20d" % -123)).to   eq("                -123")
    expect(("% 20d" % 123)).to    eq("                 123")
    expect(("%020d" % 123)).to    eq("00000000000000000123")
    expect(("%+020d" % 123)).to   eq("+0000000000000000123")
    expect(("% 020d" % 123)).to   eq(" 0000000000000000123")
    expect(("%-d" % 123)).to      eq("123")
    expect(("%-20d" % 123)).to    eq("123                 ")
    expect(("%-+20d" % 123)).to   eq("+123                ")
    expect(("%-+20d" % -123)).to  eq("-123                ")
    expect(("%- 20d" % 123)).to   eq(" 123                ")
    expect(("%s" % 'a')).to       eq("a")
    expect(("%-s" % 'a')).to      eq("a")
    expect(("%20s" % 'a')).to     eq("                   a")
    expect(("%-20s" % 'a')).to    eq("a                   ")

    expect(("%%%d" % 1)).to eq("%1")
    expect(("foo %d bar %s baz %d goo" % [1, "hello", 2])).to eq("foo 1 bar hello baz 2 goo")

    expect(("%b" % 123)).to eq("1111011")
    expect(("%+b" % 123)).to eq("+1111011")
    expect(("% b" % 123)).to eq(" 1111011")
    expect(("%-b" % 123)).to eq("1111011")
    expect(("%10b" % 123)).to eq("   1111011")
    expect(("%-10b" % 123)).to eq("1111011   ")

    expect(("%o" % 123)).to eq("173")
    expect(("%+o" % 123)).to eq("+173")
    expect(("% o" % 123)).to eq(" 173")
    expect(("%-o" % 123)).to eq("173")
    expect(("%6o" % 123)).to eq("   173")
    expect(("%-6o" % 123)).to eq("173   ")

    expect(("%x" % 123)).to eq("7B")
    expect(("%+x" % 123)).to eq("+7B")
    expect(("% x" % 123)).to eq(" 7B")
    expect(("%-x" % 123)).to eq("7B")
    expect(("%6x" % 123)).to eq("    7B")
    expect(("%-6x" % 123)).to eq("7B    ")

    expect(("こんに%xちは" % 123)).to eq("こんに7Bちは")

    expect(("%f" % 123)).to eq("123.000000")

    expect(("%g" % 123)).to eq("123")
    expect(("%12f" % 123.45)).to eq("  123.450000")
    expect(("%-12f" % 123.45)).to eq("123.450000  ")
    expect(("% f" % 123.45)).to eq(" 123.450000")
    expect(("%+f" % 123)).to eq("+123.000000")
    expect(("%012f" % 123)).to eq("00123.000000")
    expect(("%.f" % 1234.56)).to eq("1235")
    expect(("%.2f" % 1234.5678)).to eq("1234.57")
    expect(("%10.2f" % 1234.5678)).to eq("   1234.57")
    expect(("%e" % 123.45)).to eq("1.234500e+02")
    expect(("%E" % 123.45)).to eq("1.234500E+02")
    expect(("%G" % 12345678.45)).to eq("1.23457E+07")
    expect(("%a" % 12345678.45)).to eq("0x1.78c29ce666666p+23")
    expect(("%A" % 12345678.45)).to eq("0X1.78C29CE666666P+23")
    expect(("%100.50g" % 123.45)).to eq("                                                  123.4500000000000028421709430404007434844970703125")
  end

  it "escapes chars" do
    expect("\b"[0]).to eq('\b')
    expect("\t"[0]).to eq('\t')
    expect("\n"[0]).to eq('\n')
    expect("\v"[0]).to eq('\v')
    expect("\f"[0]).to eq('\f')
    expect("\r"[0]).to eq('\r')
    expect("\e"[0]).to eq('\e')
    expect("\""[0]).to eq('"')
    expect("\\"[0]).to eq('\\')
  end

  it "escapes with octal" do
    expect("\3"[0].ord).to eq(3)
    expect("\23"[0].ord).to eq((2 * 8) + 3)
    expect("\123"[0].ord).to eq((1 * 8 * 8) + (2 * 8) + 3)
    expect("\033"[0].ord).to eq((3 * 8) + 3)
    expect("\033a"[1]).to eq('a')
  end

  it "escapes with unicode" do
    expect("\u{12}".codepoint_at(0)).to eq(1 * 16 + 2)
    expect("\u{A}".codepoint_at(0)).to eq(10)
    expect("\u{AB}".codepoint_at(0)).to eq(10 * 16 + 11)
    expect("\u{AB}1".codepoint_at(1)).to eq('1'.ord)
  end

  it "does char_at" do
    expect("いただきます".char_at(2)).to eq('だ')
  end

  it "does byte_at" do
    expect("hello".byte_at(1)).to eq('e'.ord)
    expect_raises(IndexOutOfBounds) { "hello".byte_at(5) }
  end

  it "does byte_at?" do
    expect("hello".byte_at?(1)).to eq('e'.ord)
    expect("hello".byte_at?(5)).to be_nil
  end

  it "does chars" do
    expect("ぜんぶ".chars).to eq(['ぜ', 'ん', 'ぶ'])
  end

  it "allows creating a string with zeros" do
    p = Pointer(UInt8).malloc(3)
    p[0] = 'a'.ord.to_u8
    p[1] = '\0'.ord.to_u8
    p[2] = 'b'.ord.to_u8
    s = String.new(p, 3)
    expect(s[0]).to eq('a')
    expect(s[1]).to eq('\0')
    expect(s[2]).to eq('b')
    expect(s.bytesize).to eq(3)
  end

  it "tr" do
    expect("bla".tr("a", "h")).to eq("blh")
    expect("bla".tr("a", "⊙")).to eq("bl⊙")
    expect("bl⊙a".tr("⊙", "a")).to eq("blaa")
    expect("bl⊙a".tr("⊙", "ⓧ")).to eq("blⓧa")
    expect("bl⊙a⊙asdfd⊙dsfsdf⊙⊙⊙".tr("a⊙", "ⓧt")).to eq("bltⓧtⓧsdfdtdsfsdfttt")
    expect("hello".tr("aeiou", "*")).to eq("h*ll*")
    expect("hello".tr("el", "ip")).to eq("hippo")
    expect("Lisp".tr("Lisp", "Crys")).to eq("Crys")
    expect("hello".tr("helo", "1212")).to eq("12112")
    expect("this".tr("this", "ⓧ")).to eq("ⓧⓧⓧⓧ")
    expect("über".tr("ü","u")).to eq("uber")
  end

  describe "compare" do
    it "compares with == when same string" do
      expect("foo").to eq("foo")
    end

    it "compares with == when different strings same contents" do
      s1 = "foo#{1}"
      s2 = "foo#{1}"
      expect(s1).to eq(s2)
    end

    it "compares with == when different contents" do
      s1 = "foo#{1}"
      s2 = "foo#{2}"
      expect(s1).to_not eq(s2)
    end

    it "sorts strings" do
      s1 = "foo1"
      s2 = "foo"
      s3 = "bar"
      expect([s1, s2, s3].sort).to eq(["bar", "foo", "foo1"])
    end
  end

  it "does underscore" do
    expect("Foo".underscore).to eq("foo")
    expect("FooBar".underscore).to eq("foo_bar")
    expect("ABCde".underscore).to eq("ab_cde")
    expect("FOO_bar".underscore).to eq("foo_bar")
  end

  it "does camelcase" do
    expect("foo".camelcase).to eq("Foo")
    expect("foo_bar".camelcase).to eq("FooBar")
  end

  it "answers ascii_only?" do
    expect("a".ascii_only?).to be_true
    expect("あ".ascii_only?).to be_false

    str = String.new(1) do |buffer|
      buffer.value = 'a'.ord.to_u8
      {1, 0}
    end
    expect(str.ascii_only?).to be_true

    str = String.new(4) do |buffer|
      count = 0
      'あ'.each_byte do |byte|
        buffer[count] = byte
        count += 1
      end
      {count, 0}
    end
    expect(str.ascii_only?).to be_false
  end

  describe "scan" do
    it "does without block" do
      a = "cruel world"
      expect(a.scan(/\w+/).map(&.[0])).to eq(["cruel", "world"])
      expect(a.scan(/.../).map(&.[0])).to eq(["cru", "el ", "wor"])
      expect(a.scan(/(...)/).map(&.[1])).to eq(["cru", "el ", "wor"])
      expect(a.scan(/(..)(..)/).map { |m| {m[1], m[2]} }).to eq([{"cr", "ue"}, {"l ", "wo"}])
    end

    it "does with block" do
      a = "foo goo"
      i = 0
      a.scan(/\w(o+)/) do |match|
        case i
        when 0
          expect(match[0]).to eq("foo")
          expect(match[1]).to eq("oo")
        when 1
          expect(match[0]).to eq("goo")
          expect(match[1]).to eq("oo")
        else
          fail "expected two matches"
        end
        i += 1
      end
    end

    it "does with utf-8" do
      a = "こん こん"
      expect(a.scan(/こ/).map(&.[0])).to eq(["こ", "こ"])
    end

    it "works when match is empty" do
      r = %r([\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"|;.*|[^\s\[\]{}('"`,;)]*))
      expect("hello".scan(r).map(&.[0])).to eq(["hello", ""])
    end

    it "works with strings with block" do
      res = [] of String
      "bla bla ablf".scan("bl") { |s| res << s }
      expect(res).to eq(["bl", "bl", "bl"])
    end

    it "works with strings" do
      expect("bla bla ablf".scan("bl")).to eq(["bl", "bl", "bl"])
      expect("hello".scan("world")).to eq([] of String)
      expect("bbb".scan("bb")).to eq(["bb"])
      expect("ⓧⓧⓧ".scan("ⓧⓧ")).to eq(["ⓧⓧ"])
      expect("ⓧ".scan("ⓧ")).to eq(["ⓧ"])
      expect("ⓧ ⓧ ⓧ".scan("ⓧ")).to eq(["ⓧ", "ⓧ", "ⓧ"])
      expect("".scan("")).to eq([] of String)
      expect("a".scan("")).to eq([] of String)
      expect("".scan("a")).to eq([] of String)
    end

    it "does with number and string" do
      expect("1ab4".scan(/\d+/).map(&.[0])).to eq(["1", "4"])
    end
  end

  it "has match" do
    expect("FooBar".match(/oo/).not_nil![0]).to eq("oo")
  end

  it "matches with position" do
    expect("こんにちは".match(/./, 1).not_nil![0]).to eq("ん")
  end

  it "has size (same as length)" do
    expect("テスト".size).to eq(3)
  end

  describe "count" do
    assert { expect("hello world".count("lo")).to eq(5) }
    assert { expect("hello world".count("lo", "o")).to eq(2) }
    assert { expect("hello world".count("hello", "^l")).to eq(4) }
    assert { expect("hello world".count("ej-m")).to eq(4) }
    assert { expect("hello^world".count("\\^aeiou")).to eq(4) }
    assert { expect("hello-world".count("a\\-eo")).to eq(4) }
    assert { expect("hello world\\r\\n".count("\\")).to eq(2) }
    assert { expect("hello world\\r\\n".count("\\A")).to eq(0) }
    assert { expect("hello world\\r\\n".count("X-\\w")).to eq(3) }
    assert { expect("aabbcc".count('a')).to eq(2) }
    assert { expect("aabbcc".count {|c| ['a', 'b'].includes?(c) }).to eq(4) }
  end

  describe "squeeze" do
    assert { expect("aaabbbccc".squeeze {|c| ['a', 'b'].includes?(c) }).to eq("abccc") }
    assert { expect("aaabbbccc".squeeze {|c| ['a', 'c'].includes?(c) }).to eq("abbbc") }
    assert { expect("a       bbb".squeeze).to eq("a b") }
    assert { expect("a    bbb".squeeze(' ')).to eq("a bbb") }
    assert { expect("aaabbbcccddd".squeeze("b-d")).to eq("aaabcd") }
  end

  describe "ljust" do
    assert { expect("123".ljust(2)).to eq("123") }
    assert { expect("123".ljust(5)).to eq("123  ") }
    assert { expect("12".ljust(7, '-')).to eq("12-----") }
    assert { expect("12".ljust(7, 'あ')).to eq("12あああああ") }
  end

  describe "rjust" do
    assert { expect("123".rjust(2)).to eq("123") }
    assert { expect("123".rjust(5)).to eq("  123") }
    assert { expect("12".rjust(7, '-')).to eq("-----12") }
    assert { expect("12".rjust(7, 'あ')).to eq("あああああ12") }
  end

  it "uses sprintf from top-level" do
    expect(sprintf("Hello %d world", 123)).to eq("Hello 123 world")
    expect(sprintf("Hello %d world", [123])).to eq("Hello 123 world")
  end
end
