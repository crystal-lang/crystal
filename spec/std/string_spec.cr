require "spec"

describe "String" do
  describe "[]" do
    it "gets with positive index" do
      c = "hello!"[1]
      c.should be_a(Char)
      c.should eq('e')
    end

    it "gets with negative index" do
      "hello!"[-1].should eq('!')
    end

    it "gets with inclusive range" do
      "hello!"[1..4].should eq("ello")
    end

    it "gets with inclusive range with negative indices" do
      "hello!"[-5..-2].should eq("ello")
    end

    it "gets with exclusive range" do
      "hello!"[1...4].should eq("ell")
    end

    it "gets with start and count" do
      "hello"[1, 3].should eq("ell")
    end

    it "gets with exclusive range with unicode" do
      "há日本語"[1..3].should eq("á日本")
    end

    it "gets when index is last and count is zero" do
      "foo"[3, 0].should eq("")
    end

    it "gets when index is last and count is positive" do
      "foo"[3, 10].should eq("")
    end

    it "gets when index is last and count is negative at last" do
      expect_raises(ArgumentError) do
        "foo"[3, -1]
      end
    end

    assert { "foo"[3..-10].should eq("") }

    it "gets when index is last and count is negative at last with utf-8" do
      expect_raises(ArgumentError) do
        "há日本語"[5, -1]
      end
    end

    it "gets when index is last and count is zero in utf-8" do
      "há日本語"[5, 0].should eq("")
    end

    it "gets when index is last and count is positive in utf-8" do
      "há日本語"[5, 10].should eq("")
    end

    it "raises index out of bound on index out of range with range" do
      expect_raises(IndexError) do
        "foo"[4..1]
      end
    end

    it "raises index out of bound on index out of range with range and utf-8" do
      expect_raises(IndexError) do
        "há日本語"[6..1]
      end
    end

    it "gets with exclusive with start and count" do
      "há日本語"[1, 3].should eq("á日本")
    end

    it "gets with exclusive with start and count to end" do
      "há日本語"[1, 4].should eq("á日本語")
    end

    it "gets with start and count with negative start" do
      "こんいちは"[-3, 2].should eq("いち")
    end

    it "raises if index out of bounds" do
      expect_raises(IndexError) do
        "foo"[4, 1]
      end
    end

    it "raises if index out of bounds with utf-8" do
      expect_raises(IndexError) do
        "こんいちは"[6, 1]
      end
    end

    it "raises if count is negative" do
      expect_raises(ArgumentError) do
        "foo"[1, -1]
      end
    end

    it "raises if count is negative with utf-8" do
      expect_raises(ArgumentError) do
        "こんいちは"[3, -1]
      end
    end

    it "gets with single char" do
      ";"[0..-2].should eq("")
    end

    it "raises on too negative left bound" do
      expect_raises IndexError do
        "foo"[-4..0]
      end
    end

    describe "with a regex" do
      assert { "FooBar"[/o+/].should eq "oo" }
      assert { "FooBar"[/([A-Z])/, 1].should eq "F" }
      assert { "FooBar"[/x/]?.should be_nil }
      assert { "FooBar"[/x/, 1]?.should be_nil }
      assert { "FooBar"[/(x)/, 1]?.should be_nil }
      assert { "FooBar"[/o(o)/, 2]?.should be_nil }
      assert { "FooBar"[/o(?<this>o)/, "this"].should eq "o" }
      assert { "FooBar"[/(?<this>x)/, "that"]?.should be_nil }
    end

    it "gets with a string" do
      "FooBar"["Bar"].should eq "Bar"
      expect_raises { "FooBar"["Baz"] }
      "FooBar"["Bar"]?.should eq "Bar"
      "FooBar"["Baz"]?.should be_nil
    end

    it "gets with index and []?" do
      "hello"[1]?.should eq('e')
      "hello"[5]?.should be_nil
      "hello"[-1]?.should eq('o')
      "hello"[-6]?.should be_nil
    end
  end

  describe "byte_slice" do
    it "gets byte_slice" do
      "hello".byte_slice(1, 3).should eq("ell")
    end

    it "gets byte_slice with negative count" do
      expect_raises(ArgumentError) do
        "hello".byte_slice(1, -10)
      end
    end

    it "gets byte_slice with negative count at last" do
      expect_raises(ArgumentError) do
        "hello".byte_slice(5, -1)
      end
    end

    it "gets byte_slice with start out of bounds" do
      expect_raises(IndexError) do
        "hello".byte_slice(10, 3)
      end
    end

    it "gets byte_slice with large count" do
      "hello".byte_slice(1, 10).should eq("ello")
    end

    it "gets byte_slice with negative index" do
      "hello".byte_slice(-2, 3).should eq("lo")
    end
  end

  describe "to_i" do
    assert { "1234".to_i.should eq(1234) }
    assert { "   +1234   ".to_i.should eq(1234) }
    assert { "   -1234   ".to_i.should eq(-1234) }
    assert { "   +1234   ".to_i.should eq(1234) }
    assert { "   -00001234".to_i.should eq(-1234) }
    assert { "1_234".to_i(underscore: true).should eq(1234) }
    assert { "1101".to_i(base: 2).should eq(13) }
    assert { "12ab".to_i(16).should eq(4779) }
    assert { "0x123abc".to_i(prefix: true).should eq(1194684) }
    assert { "0b1101".to_i(prefix: true).should eq(13) }
    assert { "0b001101".to_i(prefix: true).should eq(13) }
    assert { "0123".to_i(prefix: true).should eq(83) }
    assert { "123hello".to_i(strict: false).should eq(123) }
    assert { "99 red balloons".to_i(strict: false).should eq(99) }
    assert { "   99 red balloons".to_i(strict: false).should eq(99) }
    assert { expect_raises(ArgumentError) { "hello".to_i } }
    assert { expect_raises(ArgumentError) { "1__234".to_i } }
    assert { expect_raises(ArgumentError) { "1_234".to_i } }
    assert { expect_raises(ArgumentError) { "   1234   ".to_i(whitespace: false) } }
    assert { expect_raises(ArgumentError) { "0x123".to_i } }
    assert { expect_raises(ArgumentError) { "0b123".to_i } }
    assert { expect_raises(ArgumentError) { "000b123".to_i(prefix: true) } }
    assert { expect_raises(ArgumentError) { "000x123".to_i(prefix: true) } }
    assert { expect_raises(ArgumentError) { "123hello".to_i } }
    assert { "z".to_i(36).should eq(35) }
    assert { "Z".to_i(36).should eq(35) }
    assert { "0".to_i(62).should eq(0) }
    assert { "1".to_i(62).should eq(1) }
    assert { "a".to_i(62).should eq(10) }
    assert { "z".to_i(62).should eq(35) }
    assert { "A".to_i(62).should eq(36) }
    assert { "Z".to_i(62).should eq(61) }
    assert { "10".to_i(62).should eq(62) }
    assert { "1z".to_i(62).should eq(97) }
    assert { "ZZ".to_i(62).should eq(3843) }

    describe "to_i8" do
      assert { "127".to_i8.should eq(127) }
      assert { "-128".to_i8.should eq(-128) }
      assert { expect_raises(ArgumentError) { "128".to_i8 } }
      assert { expect_raises(ArgumentError) { "-129".to_i8 } }

      assert { "127".to_i8?.should eq(127) }
      assert { "128".to_i8?.should be_nil }
      assert { "128".to_i8 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_i8 } }
    end

    describe "to_u8" do
      assert { "255".to_u8.should eq(255) }
      assert { "0".to_u8.should eq(0) }
      assert { expect_raises(ArgumentError) { "256".to_u8 } }
      assert { expect_raises(ArgumentError) { "-1".to_u8 } }

      assert { "255".to_u8?.should eq(255) }
      assert { "256".to_u8?.should be_nil }
      assert { "256".to_u8 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_u8 } }
    end

    describe "to_i16" do
      assert { "32767".to_i16.should eq(32767) }
      assert { "-32768".to_i16.should eq(-32768) }
      assert { expect_raises(ArgumentError) { "32768".to_i16 } }
      assert { expect_raises(ArgumentError) { "-32769".to_i16 } }

      assert { "32767".to_i16?.should eq(32767) }
      assert { "32768".to_i16?.should be_nil }
      assert { "32768".to_i16 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_i16 } }
    end

    describe "to_u16" do
      assert { "65535".to_u16.should eq(65535) }
      assert { "0".to_u16.should eq(0) }
      assert { expect_raises(ArgumentError) { "65536".to_u16 } }
      assert { expect_raises(ArgumentError) { "-1".to_u16 } }

      assert { "65535".to_u16?.should eq(65535) }
      assert { "65536".to_u16?.should be_nil }
      assert { "65536".to_u16 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_u16 } }
    end

    describe "to_i32" do
      assert { "2147483647".to_i32.should eq(2147483647) }
      assert { "-2147483648".to_i32.should eq(-2147483648) }
      assert { expect_raises(ArgumentError) { "2147483648".to_i32 } }
      assert { expect_raises(ArgumentError) { "-2147483649".to_i32 } }

      assert { "2147483647".to_i32?.should eq(2147483647) }
      assert { "2147483648".to_i32?.should be_nil }
      assert { "2147483648".to_i32 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_i32 } }
    end

    describe "to_u32" do
      assert { "4294967295".to_u32.should eq(4294967295) }
      assert { "0".to_u32.should eq(0) }
      assert { expect_raises(ArgumentError) { "4294967296".to_u32 } }
      assert { expect_raises(ArgumentError) { "-1".to_u32 } }

      assert { "4294967295".to_u32?.should eq(4294967295) }
      assert { "4294967296".to_u32?.should be_nil }
      assert { "4294967296".to_u32 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_u32 } }
    end

    describe "to_i64" do
      assert { "9223372036854775807".to_i64.should eq(9223372036854775807) }
      assert { "-9223372036854775808".to_i64.should eq(-9223372036854775808) }
      assert { expect_raises(ArgumentError) { "9223372036854775808".to_i64 } }
      assert { expect_raises(ArgumentError) { "-9223372036854775809".to_i64 } }

      assert { "9223372036854775807".to_i64?.should eq(9223372036854775807) }
      assert { "9223372036854775808".to_i64?.should be_nil }
      assert { "9223372036854775808".to_i64 { 0 }.should eq(0) }

      assert { expect_raises(ArgumentError) { "18446744073709551616".to_i64 } }
    end

    describe "to_u64" do
      assert { "18446744073709551615".to_u64.should eq(18446744073709551615) }
      assert { "0".to_u64.should eq(0) }
      assert { expect_raises(ArgumentError) { "18446744073709551616".to_u64 } }
      assert { expect_raises(ArgumentError) { "-1".to_u64 } }

      assert { "18446744073709551615".to_u64?.should eq(18446744073709551615) }
      assert { "18446744073709551616".to_u64?.should be_nil }
      assert { "18446744073709551616".to_u64 { 0 }.should eq(0) }
    end

    assert { "1234".to_i32.should eq(1234) }
    assert { "1234123412341234".to_i64.should eq(1234123412341234_i64) }
    assert { "9223372036854775808".to_u64.should eq(9223372036854775808_u64) }

    assert { expect_raises(ArgumentError, "invalid base 1") { "12ab".to_i(1) } }
    assert { expect_raises(ArgumentError, "invalid base 37") { "12ab".to_i(37) } }

    assert { expect_raises { "1Y2P0IJ32E8E7".to_i(36) } }
    assert { "1Y2P0IJ32E8E7".to_i64(36).should eq(9223372036854775807) }
  end

  it "does to_f" do
    "1234.56".to_f.should eq(1234.56_f64)
  end

  it "does to_f32" do
    "1234.56".to_f32.should eq(1234.56_f32)
  end

  it "does to_f64" do
    "1234.56".to_f64.should eq(1234.56_f64)
  end

  it "compares strings: different size" do
    "foo".should_not eq("fo")
  end

  it "compares strings: same object" do
    f = "foo"
    f.should eq(f)
  end

  it "compares strings: same size, same string" do
    "foo".should eq("fo" + "o")
  end

  it "compares strings: same size, different string" do
    "foo".should_not eq("bar")
  end

  it "interpolates string" do
    foo = "<foo>"
    bar = 123
    "foo #{bar}".should eq("foo 123")
    "foo #{bar}".should eq("foo 123")
    "#{foo} bar".should eq("<foo> bar")
  end

  it "multiplies" do
    str = "foo"
    (str * 0).should eq("")
    (str * 3).should eq("foofoofoo")
  end

  it "multiplies with size one" do
    str = "f"
    (str * 0).should eq("")
    (str * 10).should eq("ffffffffff")
  end

  it "multiplies with negative size" do
    expect_raises(ArgumentError, "negative argument") do
      "f" * -1
    end
  end

  describe "downcase" do
    assert { "HELLO!".downcase.should eq("hello!") }
    assert { "HELLO MAN!".downcase.should eq("hello man!") }
  end

  describe "upcase" do
    assert { "hello!".upcase.should eq("HELLO!") }
    assert { "hello man!".upcase.should eq("HELLO MAN!") }
  end

  describe "capitalize" do
    assert { "HELLO!".capitalize.should eq("Hello!") }
    assert { "HELLO MAN!".capitalize.should eq("Hello man!") }
    assert { "".capitalize.should eq("") }
  end

  describe "chomp" do
    assert { "hello\n".chomp.should eq("hello") }
    assert { "hello\r".chomp.should eq("hello") }
    assert { "hello\r\n".chomp.should eq("hello") }
    assert { "hello".chomp.should eq("hello") }
    assert { "hello".chomp.should eq("hello") }
    assert { "かたな\n".chomp.should eq("かたな") }
    assert { "かたな\r".chomp.should eq("かたな") }
    assert { "かたな\r\n".chomp.should eq("かたな") }
    assert { "hello\n\n".chomp.should eq("hello\n") }
    assert { "hello\r\n\n".chomp.should eq("hello\r\n") }

    assert { "hello".chomp('a').should eq("hello") }
    assert { "hello".chomp('o').should eq("hell") }
    assert { "かたな".chomp('な').should eq("かた") }

    assert { "hello".chomp("good").should eq("hello") }
    assert { "hello".chomp("llo").should eq("he") }
    assert { "かたな".chomp("たな").should eq("か") }

    assert { "hello\n\n\n\n".chomp("").should eq("hello\n\n\n\n") }
  end

  describe "chop" do
    assert { "foo".chop.should eq("fo") }
    assert { "foo\n".chop.should eq("foo") }
    assert { "foo\r".chop.should eq("foo") }
    assert { "foo\r\n".chop.should eq("foo") }
    assert { "\r\n".chop.should eq("") }
    assert { "かたな".chop.should eq("かた") }
    assert { "かたな\n".chop.should eq("かたな") }
    assert { "かたな\r\n".chop.should eq("かたな") }
  end

  describe "strip" do
    assert { "  hello  \n\t\f\v\r".strip.should eq("hello") }
    assert { "hello".strip.should eq("hello") }
    assert { "かたな \n\f\v".strip.should eq("かたな") }
    assert { "  \n\t かたな \n\f\v".strip.should eq("かたな") }
    assert { "  \n\t かたな".strip.should eq("かたな") }
    assert { "かたな".strip.should eq("かたな") }
    assert { "".strip.should eq("") }
    assert { "\n".strip.should eq("") }
    assert { "\n\t  ".strip.should eq("") }
  end

  describe "rstrip" do
    assert { "  hello  ".rstrip.should eq("  hello") }
    assert { "hello".rstrip.should eq("hello") }
    assert { "  かたな \n\f\v".rstrip.should eq("  かたな") }
    assert { "かたな".rstrip.should eq("かたな") }
  end

  describe "lstrip" do
    assert { "  hello  ".lstrip.should eq("hello  ") }
    assert { "hello".lstrip.should eq("hello") }
    assert { "  \n\v かたな  ".lstrip.should eq("かたな  ") }
    assert { "  かたな".lstrip.should eq("かたな") }
  end

  describe "empty?" do
    assert { "a".empty?.should be_false }
    assert { "".empty?.should be_true }
  end

  describe "index" do
    describe "by char" do
      assert { "foo".index('o').should eq(1) }
      assert { "foo".index('g').should be_nil }
      assert { "bar".index('r').should eq(2) }
      assert { "日本語".index('本').should eq(1) }
      assert { "bar".index('あ').should be_nil }

      describe "with offset" do
        assert { "foobarbaz".index('a', 5).should eq(7) }
        assert { "foobarbaz".index('a', -4).should eq(7) }
        assert { "foo".index('g', 1).should be_nil }
        assert { "foo".index('g', -20).should be_nil }
        assert { "日本語日本語".index('本', 2).should eq(4) }
      end
    end

    describe "by string" do
      assert { "foo bar".index("o b").should eq(2) }
      assert { "foo".index("fg").should be_nil }
      assert { "foo".index("").should eq(0) }
      assert { "foo".index("foo").should eq(0) }
      assert { "日本語日本語".index("本語").should eq(1) }

      describe "with offset" do
        assert { "foobarbaz".index("ba", 4).should eq(6) }
        assert { "foobarbaz".index("ba", -5).should eq(6) }
        assert { "foo".index("ba", 1).should be_nil }
        assert { "foo".index("ba", -20).should be_nil }
        assert { "日本語日本語".index("本語", 2).should eq(4) }
      end
    end
  end

  describe "rindex" do
    describe "by char" do
      assert { "foobar".rindex('a').should eq(4) }
      assert { "foobar".rindex('g').should be_nil }
      assert { "日本語日本語".rindex('本').should eq(4) }

      describe "with offset" do
        assert { "faobar".rindex('a', 3).should eq(1) }
        assert { "faobarbaz".rindex('a', -3).should eq(4) }
        assert { "日本語日本語".rindex('本', 3).should eq(1) }
      end
    end

    describe "by string" do
      assert { "foo baro baz".rindex("o b").should eq(7) }
      assert { "foo baro baz".rindex("fg").should be_nil }
      assert { "日本語日本語".rindex("日本").should eq(3) }

      describe "with offset" do
        assert { "foo baro baz".rindex("o b", 6).should eq(2) }
        assert { "foo baro baz".rindex("fg").should be_nil }
        assert { "日本語日本語".rindex("日本", 2).should eq(0) }
      end
    end
  end

  describe "byte_index" do
    assert { "foo".byte_index('o'.ord).should eq(1) }
    assert { "foo bar booz".byte_index('o'.ord, 3).should eq(9) }
    assert { "foo".byte_index('a'.ord).should be_nil }

    it "gets byte index of string" do
      "hello world".byte_index("lo").should eq(3)
    end
  end

  describe "includes?" do
    describe "by char" do
      assert { "foo".includes?('o').should be_true }
      assert { "foo".includes?('g').should be_false }
    end

    describe "by string" do
      assert { "foo bar".includes?("o b").should be_true }
      assert { "foo".includes?("fg").should be_false }
      assert { "foo".includes?("").should be_true }
    end
  end

  describe "split" do
    describe "by char" do
      assert { "".split(',').should eq([""]) }
      assert { "foo,bar,,baz,".split(',').should eq(["foo", "bar", "", "baz", ""]) }
      assert { "foo,bar,,baz".split(',').should eq(["foo", "bar", "", "baz"]) }
      assert { "foo".split(',').should eq(["foo"]) }
      assert { "foo".split(' ').should eq(["foo"]) }
      assert { "   foo".split(' ').should eq(["", "", "", "foo"]) }
      assert { "foo   ".split(' ').should eq(["foo", "", "", ""]) }
      assert { "   foo  bar".split(' ').should eq(["", "", "", "foo", "", "bar"]) }
      assert { "   foo   bar\n\t  baz   ".split(' ').should eq(["", "", "", "foo", "", "", "bar\n\t", "", "baz", "", "", ""]) }
      assert { "   foo   bar\n\t  baz   ".split.should eq(["foo", "bar", "baz"]) }
      assert { "   foo   bar\n\t  baz   ".split(2).should eq(["foo", "bar\n\t  baz   "]) }
      assert { "   foo   bar\n\t  baz   ".split(" ").should eq(["", "", "", "foo", "", "", "bar\n\t", "", "baz", "", "", ""]) }
      assert { "foo,bar,baz,qux".split(',', 1).should eq(["foo,bar,baz,qux"]) }
      assert { "foo,bar,baz,qux".split(',', 3).should eq(["foo", "bar", "baz,qux"]) }
      assert { "foo,bar,baz,qux".split(',', 30).should eq(["foo", "bar", "baz", "qux"]) }
      assert { "foo bar baz qux".split(' ', 1).should eq(["foo bar baz qux"]) }
      assert { "foo bar baz qux".split(' ', 3).should eq(["foo", "bar", "baz qux"]) }
      assert { "foo bar baz qux".split(' ', 30).should eq(["foo", "bar", "baz", "qux"]) }
      assert { "a,b,".split(',', 3).should eq(["a", "b", ""]) }
      assert { "日本語 \n\t 日本 \n\n 語".split.should eq(["日本語", "日本", "語"]) }
      assert { "日本ん語日本ん語".split('ん').should eq(["日本", "語日本", "語"]) }
      assert { "=".split('=').should eq(["", ""]) }
      assert { "a=".split('=').should eq(["a", ""]) }
      assert { "=b".split('=').should eq(["", "b"]) }
      assert { "=".split('=', 2).should eq(["", ""]) }
    end

    describe "by string" do
      assert { "".split(",").should eq([""]) }
      assert { "".split(":-").should eq([""]) }
      assert { "foo:-bar:-:-baz:-".split(":-").should eq(["foo", "bar", "", "baz", ""]) }
      assert { "foo:-bar:-:-baz".split(":-").should eq(["foo", "bar", "", "baz"]) }
      assert { "foo".split(":-").should eq(["foo"]) }
      assert { "foo".split("").should eq(["f", "o", "o"]) }
      assert { "日本さん語日本さん語".split("さん").should eq(["日本", "語日本", "語"]) }
      assert { "foo,bar,baz,qux".split(",", 1).should eq(["foo,bar,baz,qux"]) }
      assert { "foo,bar,baz,qux".split(",", 3).should eq(["foo", "bar", "baz,qux"]) }
      assert { "foo,bar,baz,qux".split(",", 30).should eq(["foo", "bar", "baz", "qux"]) }
      assert { "a b c".split(" ", 2).should eq(["a", "b c"]) }
      assert { "=".split("=").should eq(["", ""]) }
      assert { "a=".split("=").should eq(["a", ""]) }
      assert { "=b".split("=").should eq(["", "b"]) }
      assert { "=".split("=", 2).should eq(["", ""]) }
    end

    describe "by regex" do
      assert { "".split(/\n\t/).should eq([""] of String) }
      assert { "foo\n\tbar\n\t\n\tbaz".split(/\n\t/).should eq(["foo", "bar", "", "baz"]) }
      assert { "foo\n\tbar\n\t\n\tbaz".split(/(?:\n\t)+/).should eq(["foo", "bar", "baz"]) }
      assert { "foo,bar".split(/,/, 1).should eq(["foo,bar"]) }
      assert { "foo,bar,".split(/,/).should eq(["foo", "bar", ""]) }
      assert { "foo,bar,baz,qux".split(/,/, 1).should eq(["foo,bar,baz,qux"]) }
      assert { "foo,bar,baz,qux".split(/,/, 3).should eq(["foo", "bar", "baz,qux"]) }
      assert { "foo,bar,baz,qux".split(/,/, 30).should eq(["foo", "bar", "baz", "qux"]) }
      assert { "a b c".split(Regex.new(" "), 2).should eq(["a", "b c"]) }
      assert { "日本ん語日本ん語".split(/ん/).should eq(["日本", "語日本", "語"]) }
      assert { "hello world".split(/\b/).should eq(["hello", " ", "world", ""]) }
      assert { "abc".split(//).should eq(["a", "b", "c"]) }
      assert { "hello".split(/\w+/).should eq(["", ""]) }
      assert { "foo".split(/o/).should eq(["f", "", ""]) }
      assert { "=".split(/\=/).should eq(["", ""]) }
      assert { "a=".split(/\=/).should eq(["a", ""]) }
      assert { "=b".split(/\=/).should eq(["", "b"]) }
      assert { "=".split(/\=/, 2).should eq(["", ""]) }

      it "keeps groups" do
        s = "split on the word on okay?"
        s.split(/(on)/).should eq(["split ", "on", " the word ", "on", " okay?"])
      end
    end
  end

  describe "starts_with?" do
    assert { "foobar".starts_with?("foo").should be_true }
    assert { "foobar".starts_with?("").should be_true }
    assert { "foobar".starts_with?("foobarbaz").should be_false }
    assert { "foobar".starts_with?("foox").should be_false }
    assert { "foobar".starts_with?('f').should be_true }
    assert { "foobar".starts_with?('g').should be_false }
    assert { "よし".starts_with?('よ').should be_true }
    assert { "よし!".starts_with?("よし").should be_true }
  end

  describe "ends_with?" do
    assert { "foobar".ends_with?("bar").should be_true }
    assert { "foobar".ends_with?("").should be_true }
    assert { "foobar".ends_with?("foobarbaz").should be_false }
    assert { "foobar".ends_with?("xbar").should be_false }
    assert { "foobar".ends_with?('r').should be_true }
    assert { "foobar".ends_with?('x').should be_false }
    assert { "よし".ends_with?('し').should be_true }
    assert { "よし".ends_with?('な').should be_false }
  end

  describe "=~" do
    it "matches with group" do
      "foobar" =~ /(o+)ba(r?)/
      $1.should eq("oo")
      $2.should eq("r")
    end

    it "returns nil with string" do
      ("foo" =~ "foo").should be_nil
    end

    it "returns nil with regex and regex" do
      (/foo/ =~ /foo/).should be_nil
    end
  end

  describe "delete" do
    assert { "foobar".delete { |char| char == 'o' }.should eq("fbar") }
    assert { "hello world".delete("lo").should eq("he wrd") }
    assert { "hello world".delete("lo", "o").should eq("hell wrld") }
    assert { "hello world".delete("hello", "^l").should eq("ll wrld") }
    assert { "hello world".delete("ej-m").should eq("ho word") }
    assert { "hello^world".delete("\\^aeiou").should eq("hllwrld") }
    assert { "hello-world".delete("a\\-eo").should eq("hllwrld") }
    assert { "hello world\\r\\n".delete("\\").should eq("hello worldrn") }
    assert { "hello world\\r\\n".delete("\\A").should eq("hello world\\r\\n") }
    assert { "hello world\\r\\n".delete("X-\\w").should eq("hello orldrn") }

    it "deletes one char" do
      deleted = "foobar".delete('o')
      deleted.bytesize.should eq(4)
      deleted.should eq("fbar")

      deleted = "foobar".delete('x')
      deleted.bytesize.should eq(6)
      deleted.should eq("foobar")
    end
  end

  it "reverses string" do
    reversed = "foobar".reverse
    reversed.bytesize.should eq(6)
    reversed.should eq("raboof")
  end

  it "reverses utf-8 string" do
    reversed = "こんいちは".reverse
    reversed.bytesize.should eq(15)
    reversed.size.should eq(5)
    reversed.should eq("はちいんこ")
  end

  describe "sub" do
    it "subs char with char" do
      replaced = "foobar".sub('o', 'e')
      replaced.bytesize.should eq(6)
      replaced.should eq("feobar")
    end

    it "subs char with string" do
      replaced = "foobar".sub('o', "ex")
      replaced.bytesize.should eq(7)
      replaced.should eq("fexobar")
    end

    it "subs char with string" do
      replaced = "foobar".sub { |char|
        char.should eq 'f'
        "some"
      }
      replaced.bytesize.should eq(9)
      replaced.should eq("someoobar")

      empty = ""
      empty.sub { 'f' }.should be(empty)
    end

    it "subs with regex and block" do
      actual = "foo booor booooz".sub(/o+/) { |str|
        "#{str}#{str.size}"
      }
      actual.should eq("foo2 booor booooz")
    end

    it "subs with regex and block with group" do
      actual = "foo booor booooz".sub(/(o+).*?(o+)/) { |str, match|
        "#{match[1].size}#{match[2].size}"
      }
      actual.should eq("f23r booooz")
    end

    it "subs with regex and string" do
      "foo boor booooz".sub(/o+/, "a").should eq("fa boor booooz")
    end

    it "subs with regex and string, returns self if no match" do
      str = "hello"
      str.sub(/a/, "b").should be(str)
    end

    it "subs with regex and string (utf-8)" do
      "fここ bここr bここここz".sub(/こ+/, "そこ").should eq("fそこ bここr bここここz")
    end

    it "subs with empty string" do
      "foo".sub("", "x").should eq("xfoo")
    end

    it "subs with empty regex" do
      "foo".sub(//, "x").should eq("xfoo")
    end

    it "subs null character" do
      null = "\u{0}"
      "f\u{0}\u{0}".sub(/#{null}/, "o").should eq("fo\u{0}")
    end

    it "subs with string and string" do
      "foo boor booooz".sub("oo", "a").should eq("fa boor booooz")
    end

    it "subs with string and string return self if no match" do
      str = "hello"
      str.sub("a", "b").should be(str)
    end

    it "subs with string and string (utf-8)" do
      "fここ bここr bここここz".sub("ここ", "そこ").should eq("fそこ bここr bここここz")
    end

    it "subs with string and block" do
      result = "foo boo".sub("oo") { |value|
        value.should eq("oo")
        "a"
      }
      result.should eq("fa boo")
    end

    it "subs with char hash" do
      str = "hello"
      str.sub({'e' => 'a', 'l' => 'd'}).should eq("hallo")

      empty = ""
      empty.sub({'a' => 'b'}).should be(empty)
    end

    it "subs with regex and hash" do
      str = "hello"
      str.sub(/(he|l|o)/, {"he": "ha", "l": "la"}).should eq("hallo")
      str.sub(/(he|l|o)/, {"l": "la"}).should be(str)
    end

    it "subs using $~" do
      "foo".sub(/(o)/) { "x#{$1}x" }.should eq("fxoxo")
    end

    it "subs using with \\" do
      "foo".sub(/(o)/, "\\").should eq("f\\o")
    end

    it "subs using with z\\w" do
      "foo".sub(/(o)/, "z\\w").should eq("fz\\wo")
    end

    it "replaces with numeric back-reference" do
      "foo".sub(/o/, "x\\0x").should eq("fxoxo")
      "foo".sub(/(o)/, "x\\1x").should eq("fxoxo")
      "foo".sub(/(o)/, "\\\\1").should eq("f\\1o")
      "hello".sub(/[aeiou]/, "(\\0)").should eq("h(e)llo")
    end

    it "replaces with incomplete named back-reference (1)" do
      "foo".sub(/(oo)/, "|\\k|").should eq("f|\\k|")
    end

    it "replaces with incomplete named back-reference (2)" do
      "foo".sub(/(oo)/, "|\\k\\1|").should eq("f|\\koo|")
    end

    it "replaces with named back-reference" do
      "foo".sub(/(?<bar>oo)/, "|\\k<bar>|").should eq("f|oo|")
    end

    it "replaces with multiple named back-reference" do
      "fooxx".sub(/(?<bar>oo)(?<baz>x+)/, "|\\k<bar>|\\k<baz>|").should eq("f|oo|xx|")
    end

    it "replaces with \\a" do
      "foo".sub(/(oo)/, "|\\a|").should eq("f|\\a|")
    end

    it "replaces with \\\\\\1" do
      "foo".sub(/(oo)/, "|\\\\\\1|").should eq("f|\\oo|")
    end

    it "ignores if backreferences: false" do
      "foo".sub(/o/, "x\\0x", backreferences: false).should eq("fx\\0xo")
    end
  end

  describe "gsub" do
    it "gsubs char with char" do
      replaced = "foobar".gsub('o', 'e')
      replaced.bytesize.should eq(6)
      replaced.should eq("feebar")
    end

    it "gsubs char with string" do
      replaced = "foobar".gsub('o', "ex")
      replaced.bytesize.should eq(8)
      replaced.should eq("fexexbar")
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
      replaced.bytesize.should eq(18)
      replaced.should eq("somethingthingbexr")
    end

    it "gsubs with regex and block" do
      actual = "foo booor booooz".gsub(/o+/) do |str|
        "#{str}#{str.size}"
      end
      actual.should eq("foo2 booo3r boooo4z")
    end

    it "gsubs with regex and block with group" do
      actual = "foo booor booooz".gsub(/(o+).*?(o+)/) do |str, match|
        "#{match[1].size}#{match[2].size}"
      end
      actual.should eq("f23r b31z")
    end

    it "gsubs with regex and string" do
      "foo boor booooz".gsub(/o+/, "a").should eq("fa bar baz")
    end

    it "gsubs with regex and string, returns self if no match" do
      str = "hello"
      str.gsub(/a/, "b").should be(str)
    end

    it "gsubs with regex and string (utf-8)" do
      "fここ bここr bここここz".gsub(/こ+/, "そこ").should eq("fそこ bそこr bそこz")
    end

    it "gsubs with empty string" do
      "foo".gsub("", "x").should eq("xfxoxox")
    end

    it "gsubs with empty regex" do
      "foo".gsub(//, "x").should eq("xfxoxox")
    end

    it "gsubs null character" do
      null = "\u{0}"
      "f\u{0}\u{0}".gsub(/#{null}/, "o").should eq("foo")
    end

    it "gsubs with string and string" do
      "foo boor booooz".gsub("oo", "a").should eq("fa bar baaz")
    end

    it "gsubs with string and string return self if no match" do
      str = "hello"
      str.gsub("a", "b").should be(str)
    end

    it "gsubs with string and string (utf-8)" do
      "fここ bここr bここここz".gsub("ここ", "そこ").should eq("fそこ bそこr bそこそこz")
    end

    it "gsubs with string and block" do
      i = 0
      result = "foo boo".gsub("oo") do |value|
        value.should eq("oo")
        i += 1
        i == 1 ? "a" : "e"
      end
      result.should eq("fa be")
    end

    it "gsubs with char hash" do
      str = "hello"
      str.gsub({'e' => 'a', 'l' => 'd'}).should eq("haddo")
    end

    it "gsubs with regex and hash" do
      str = "hello"
      str.gsub(/(he|l|o)/, {"he": "ha", "l": "la"}).should eq("halala")
    end

    it "gsubs using $~" do
      "foo".gsub(/(o)/) { "x#{$1}x" }.should eq("fxoxxox")
    end

    it "replaces with numeric back-reference" do
      "foo".gsub(/o/, "x\\0x").should eq("fxoxxox")
      "foo".gsub(/(o)/, "x\\1x").should eq("fxoxxox")
      "foo".gsub(/(ここ)|(oo)/, "x\\1\\2x").should eq("fxoox")
    end

    it "replaces with named back-reference" do
      "foo".gsub(/(?<bar>oo)/, "|\\k<bar>|").should eq("f|oo|")
      "foo".gsub(/(?<x>ここ)|(?<bar>oo)/, "|\\k<bar>|").should eq("f|oo|")
    end

    it "replaces with incomplete back-reference (1)" do
      "foo".gsub(/o/, "\\").should eq("f\\\\")
    end

    it "replaces with incomplete back-reference (2)" do
      "foo".gsub(/o/, "\\\\").should eq("f\\\\")
    end

    it "replaces with incomplete back-reference (3)" do
      "foo".gsub(/o/, "\\k").should eq("f\\k\\k")
    end

    it "raises with incomplete back-reference (1)" do
      expect_raises(ArgumentError) do
        "foo".gsub(/(?<bar>oo)/, "|\\k<bar|")
      end
    end

    it "raises with incomplete back-reference (2)" do
      expect_raises(ArgumentError, "missing ending '>' for '\\\\k<...") do
        "foo".gsub(/o/, "\\k<")
      end
    end

    it "replaces with back-reference to missing capture group" do
      "foo".gsub(/o/, "\\1").should eq("f")

      expect_raises(IndexError, "undefined group name reference: \"bar\"") do
        "foo".gsub(/o/, "\\k<bar>").should eq("f")
      end

      expect_raises(IndexError, "undefined group name reference: \"\"") do
        "foo".gsub(/o/, "\\k<>")
      end
    end

    it "replaces with escaped back-reference" do
      "foo".gsub(/o/, "\\\\0").should eq("f\\0\\0")
      "foo".gsub(/oo/, "\\\\k<bar>").should eq("f\\k<bar>")
    end

    it "ignores if backreferences: false" do
      "foo".gsub(/o/, "x\\0x", backreferences: false).should eq("fx\\0xx\\0x")
    end
  end

  it "scans using $~" do
    str = String.build do |str|
      "fooxooo".scan(/(o+)/) { str << $1 }
    end
    str.should eq("ooooo")
  end

  it "dumps" do
    "a".dump.should eq("\"a\"")
    "\\".dump.should eq("\"\\\\\"")
    "\"".dump.should eq("\"\\\"\"")
    "\b".dump.should eq("\"\\b\"")
    "\e".dump.should eq("\"\\e\"")
    "\f".dump.should eq("\"\\f\"")
    "\n".dump.should eq("\"\\n\"")
    "\r".dump.should eq("\"\\r\"")
    "\t".dump.should eq("\"\\t\"")
    "\v".dump.should eq("\"\\v\"")
    "\#{".dump.should eq("\"\\\#{\"")
    "á".dump.should eq("\"\\u{e1}\"")
    "\u{81}".dump.should eq("\"\\u{81}\"")
  end

  it "dumps unquoted" do
    "a".dump_unquoted.should eq("a")
    "\\".dump_unquoted.should eq("\\\\")
    "á".dump_unquoted.should eq("\\u{e1}")
    "\u{81}".dump_unquoted.should eq("\\u{81}")
  end

  it "inspects" do
    "a".inspect.should eq("\"a\"")
    "\\".inspect.should eq("\"\\\\\"")
    "\"".inspect.should eq("\"\\\"\"")
    "\b".inspect.should eq("\"\\b\"")
    "\e".inspect.should eq("\"\\e\"")
    "\f".inspect.should eq("\"\\f\"")
    "\n".inspect.should eq("\"\\n\"")
    "\r".inspect.should eq("\"\\r\"")
    "\t".inspect.should eq("\"\\t\"")
    "\v".inspect.should eq("\"\\v\"")
    "\#{".inspect.should eq("\"\\\#{\"")
    "á".inspect.should eq("\"á\"")
    "\u{81}".inspect.should eq("\"\\u{81}\"")
  end

  it "inspects unquoted" do
    "a".inspect_unquoted.should eq("a")
    "\\".inspect_unquoted.should eq("\\\\")
    "á".inspect_unquoted.should eq("á")
    "\u{81}".inspect_unquoted.should eq("\\u{81}")
  end

  it "does *" do
    str = "foo" * 10
    str.bytesize.should eq(30)
    str.should eq("foofoofoofoofoofoofoofoofoofoo")
  end

  describe "+" do
    it "does for both ascii" do
      str = "foo" + "bar"
      str.bytesize.should eq(6)
      str.@length.should eq(6)
      str.should eq("foobar")
    end

    it "does for both unicode" do
      str = "青い" + "旅路"
      str.@length.should eq(4)
      str.should eq("青い旅路")
    end

    it "does with ascii char" do
      str = "foo"
      str2 = str + '/'
      str2.should eq("foo/")
      str2.bytesize.should eq(4)
      str2.size.should eq(4)
    end

    it "does with unicode char" do
      str = "fooba"
      str2 = str + 'る'
      str2.should eq("foobaる")
      str2.bytesize.should eq(8)
      str2.size.should eq(6)
    end
  end

  it "does %" do
    ("foo" % 1).should eq("foo")
    ("foo %d" % 1).should eq("foo 1")
    ("%d" % 123).should eq("123")
    ("%+d" % 123).should eq("+123")
    ("%+d" % -123).should eq("-123")
    ("% d" % 123).should eq(" 123")
    ("%i" % 123).should eq("123")
    ("%+i" % 123).should eq("+123")
    ("%+i" % -123).should eq("-123")
    ("% i" % 123).should eq(" 123")
    ("%20d" % 123).should eq("                 123")
    ("%+20d" % 123).should eq("                +123")
    ("%+20d" % -123).should eq("                -123")
    ("% 20d" % 123).should eq("                 123")
    ("%020d" % 123).should eq("00000000000000000123")
    ("%+020d" % 123).should eq("+0000000000000000123")
    ("% 020d" % 123).should eq(" 0000000000000000123")
    ("%-d" % 123).should eq("123")
    ("%-20d" % 123).should eq("123                 ")
    ("%-+20d" % 123).should eq("+123                ")
    ("%-+20d" % -123).should eq("-123                ")
    ("%- 20d" % 123).should eq(" 123                ")
    ("%s" % 'a').should eq("a")
    ("%-s" % 'a').should eq("a")
    ("%20s" % 'a').should eq("                   a")
    ("%-20s" % 'a').should eq("a                   ")
    ("%*s" % [10, 123]).should eq("       123")
    ("%.5s" % "foo bar baz").should eq("foo b")
    ("%.*s" % [5, "foo bar baz"]).should eq("foo b")
    ("%*.*s" % [20, 5, "foo bar baz"]).should eq("               foo b")
    ("%-*.*s" % [20, 5, "foo bar baz"]).should eq("foo b               ")

    ("%%%d" % 1).should eq("%1")
    ("foo %d bar %s baz %d goo" % [1, "hello", 2]).should eq("foo 1 bar hello baz 2 goo")

    ("%b" % 123).should eq("1111011")
    ("%+b" % 123).should eq("+1111011")
    ("% b" % 123).should eq(" 1111011")
    ("%-b" % 123).should eq("1111011")
    ("%10b" % 123).should eq("   1111011")
    ("%-10b" % 123).should eq("1111011   ")

    ("%o" % 123).should eq("173")
    ("%+o" % 123).should eq("+173")
    ("% o" % 123).should eq(" 173")
    ("%-o" % 123).should eq("173")
    ("%6o" % 123).should eq("   173")
    ("%-6o" % 123).should eq("173   ")

    ("%x" % 123).should eq("7b")
    ("%+x" % 123).should eq("+7b")
    ("% x" % 123).should eq(" 7b")
    ("%-x" % 123).should eq("7b")
    ("%6x" % 123).should eq("    7b")
    ("%-6x" % 123).should eq("7b    ")

    ("%X" % 123).should eq("7B")
    ("%+X" % 123).should eq("+7B")
    ("% X" % 123).should eq(" 7B")
    ("%-X" % 123).should eq("7B")
    ("%6X" % 123).should eq("    7B")
    ("%-6X" % 123).should eq("7B    ")

    ("こんに%xちは" % 123).should eq("こんに7bちは")
    ("こんに%Xちは" % 123).should eq("こんに7Bちは")

    ("%f" % 123).should eq("123.000000")

    ("%g" % 123).should eq("123")
    ("%12f" % 123.45).should eq("  123.450000")
    ("%-12f" % 123.45).should eq("123.450000  ")
    ("% f" % 123.45).should eq(" 123.450000")
    ("%+f" % 123).should eq("+123.000000")
    ("%012f" % 123).should eq("00123.000000")
    ("%.f" % 1234.56).should eq("1235")
    ("%.2f" % 1234.5678).should eq("1234.57")
    ("%10.2f" % 1234.5678).should eq("   1234.57")
    ("%*.2f" % [10, 1234.5678]).should eq("   1234.57")
    ("%0*.2f" % [10, 1234.5678]).should eq("0001234.57")
    ("%e" % 123.45).should eq("1.234500e+02")
    ("%E" % 123.45).should eq("1.234500E+02")
    ("%G" % 12345678.45).should eq("1.23457E+07")
    ("%a" % 12345678.45).should eq("0x1.78c29ce666666p+23")
    ("%A" % 12345678.45).should eq("0X1.78C29CE666666P+23")
    ("%100.50g" % 123.45).should eq("                                                  123.4500000000000028421709430404007434844970703125")

    span = 1.second
    ("%s" % span).should eq(span.to_s)

    ("%.2f" % 2.536_f32).should eq("2.54")
    ("%0*.*f" % [10, 2, 2.536_f32]).should eq("0000002.54")
    expect_raises(ArgumentError, "expected dynamic value '*' to be an Int - \"not a number\" (String)") do
      "%*f" % ["not a number", 2.536_f32]
    end
  end

  it "escapes chars" do
    "\b"[0].should eq('\b')
    "\t"[0].should eq('\t')
    "\n"[0].should eq('\n')
    "\v"[0].should eq('\v')
    "\f"[0].should eq('\f')
    "\r"[0].should eq('\r')
    "\e"[0].should eq('\e')
    "\""[0].should eq('"')
    "\\"[0].should eq('\\')
  end

  it "escapes with octal" do
    "\3"[0].ord.should eq(3)
    "\23"[0].ord.should eq((2 * 8) + 3)
    "\123"[0].ord.should eq((1 * 8 * 8) + (2 * 8) + 3)
    "\033"[0].ord.should eq((3 * 8) + 3)
    "\033a"[1].should eq('a')
  end

  it "escapes with unicode" do
    "\u{12}".codepoint_at(0).should eq(1 * 16 + 2)
    "\u{A}".codepoint_at(0).should eq(10)
    "\u{AB}".codepoint_at(0).should eq(10 * 16 + 11)
    "\u{AB}1".codepoint_at(1).should eq('1'.ord)
  end

  it "does char_at" do
    "いただきます".char_at(2).should eq('だ')
  end

  it "does byte_at" do
    "hello".byte_at(1).should eq('e'.ord)
    expect_raises(IndexError) { "hello".byte_at(5) }
  end

  it "does byte_at?" do
    "hello".byte_at?(1).should eq('e'.ord)
    "hello".byte_at?(5).should be_nil
  end

  it "does chars" do
    "ぜんぶ".chars.should eq(['ぜ', 'ん', 'ぶ'])
  end

  it "allows creating a string with zeros" do
    p = Pointer(UInt8).malloc(3)
    p[0] = 'a'.ord.to_u8
    p[1] = '\0'.ord.to_u8
    p[2] = 'b'.ord.to_u8
    s = String.new(p, 3)
    s[0].should eq('a')
    s[1].should eq('\0')
    s[2].should eq('b')
    s.bytesize.should eq(3)
  end

  it "tr" do
    "bla".tr("a", "h").should eq("blh")
    "bla".tr("a", "⊙").should eq("bl⊙")
    "bl⊙a".tr("⊙", "a").should eq("blaa")
    "bl⊙a".tr("⊙", "ⓧ").should eq("blⓧa")
    "bl⊙a⊙asdfd⊙dsfsdf⊙⊙⊙".tr("a⊙", "ⓧt").should eq("bltⓧtⓧsdfdtdsfsdfttt")
    "hello".tr("aeiou", "*").should eq("h*ll*")
    "hello".tr("el", "ip").should eq("hippo")
    "Lisp".tr("Lisp", "Crys").should eq("Crys")
    "hello".tr("helo", "1212").should eq("12112")
    "this".tr("this", "ⓧ").should eq("ⓧⓧⓧⓧ")
    "über".tr("ü", "u").should eq("uber")
  end

  describe "compare" do
    it "compares with == when same string" do
      "foo".should eq("foo")
    end

    it "compares with == when different strings same contents" do
      s1 = "foo#{1}"
      s2 = "foo#{1}"
      s1.should eq(s2)
    end

    it "compares with == when different contents" do
      s1 = "foo#{1}"
      s2 = "foo#{2}"
      s1.should_not eq(s2)
    end

    it "sorts strings" do
      s1 = "foo1"
      s2 = "foo"
      s3 = "bar"
      [s1, s2, s3].sort.should eq(["bar", "foo", "foo1"])
    end
  end

  it "does underscore" do
    "Foo".underscore.should eq("foo")
    "FooBar".underscore.should eq("foo_bar")
    "ABCde".underscore.should eq("ab_cde")
    "FOO_bar".underscore.should eq("foo_bar")
    "Char_S".underscore.should eq("char_s")
    "Char_".underscore.should eq("char_")
    "C_".underscore.should eq("c_")
    "HTTP".underscore.should eq("http")
    "HTTP_CLIENT".underscore.should eq("http_client")
  end

  it "does camelcase" do
    "foo".camelcase.should eq("Foo")
    "foo_bar".camelcase.should eq("FooBar")
  end

  it "answers ascii_only?" do
    "a".ascii_only?.should be_true
    "あ".ascii_only?.should be_false

    str = String.new(1) do |buffer|
      buffer.value = 'a'.ord.to_u8
      {1, 0}
    end
    str.ascii_only?.should be_true

    str = String.new(4) do |buffer|
      count = 0
      'あ'.each_byte do |byte|
        buffer[count] = byte
        count += 1
      end
      {count, 0}
    end
    str.ascii_only?.should be_false
  end

  describe "scan" do
    it "does without block" do
      a = "cruel world"
      a.scan(/\w+/).map(&.[0]).should eq(["cruel", "world"])
      a.scan(/.../).map(&.[0]).should eq(["cru", "el ", "wor"])
      a.scan(/(...)/).map(&.[1]).should eq(["cru", "el ", "wor"])
      a.scan(/(..)(..)/).map { |m| {m[1], m[2]} }.should eq([{"cr", "ue"}, {"l ", "wo"}])
    end

    it "does with block" do
      a = "foo goo"
      i = 0
      a.scan(/\w(o+)/) do |match|
        case i
        when 0
          match[0].should eq("foo")
          match[1].should eq("oo")
        when 1
          match[0].should eq("goo")
          match[1].should eq("oo")
        else
          fail "expected two matches"
        end
        i += 1
      end
    end

    it "does with utf-8" do
      a = "こん こん"
      a.scan(/こ/).map(&.[0]).should eq(["こ", "こ"])
    end

    it "works when match is empty" do
      r = %r([\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"|;.*|[^\s\[\]{}('"`,;)]*))
      "hello".scan(r).map(&.[0]).should eq(["hello", ""])
    end

    it "works with strings with block" do
      res = [] of String
      "bla bla ablf".scan("bl") { |s| res << s }
      res.should eq(["bl", "bl", "bl"])
    end

    it "works with strings" do
      "bla bla ablf".scan("bl").should eq(["bl", "bl", "bl"])
      "hello".scan("world").should eq([] of String)
      "bbb".scan("bb").should eq(["bb"])
      "ⓧⓧⓧ".scan("ⓧⓧ").should eq(["ⓧⓧ"])
      "ⓧ".scan("ⓧ").should eq(["ⓧ"])
      "ⓧ ⓧ ⓧ".scan("ⓧ").should eq(["ⓧ", "ⓧ", "ⓧ"])
      "".scan("").should eq([] of String)
      "a".scan("").should eq([] of String)
      "".scan("a").should eq([] of String)
    end

    it "does with number and string" do
      "1ab4".scan(/\d+/).map(&.[0]).should eq(["1", "4"])
    end
  end

  it "has match" do
    "FooBar".match(/oo/).not_nil![0].should eq("oo")
  end

  it "matches with position" do
    "こんにちは".match(/./, 1).not_nil![0].should eq("ん")
  end

  it "matches with block" do
    "FooBar".match(/oo/) do |match_data|
      match_data[0].should eq("oo")
    end
  end

  it "matches empty string" do
    match = "".match(/.*/).not_nil!
    match.size.should eq(0)
    match[0].should eq("")
  end

  it "has size (same as size)" do
    "テスト".size.should eq(3)
  end

  describe "count" do
    assert { "hello world".count("lo").should eq(5) }
    assert { "hello world".count("lo", "o").should eq(2) }
    assert { "hello world".count("hello", "^l").should eq(4) }
    assert { "hello world".count("ej-m").should eq(4) }
    assert { "hello^world".count("\\^aeiou").should eq(4) }
    assert { "hello-world".count("a\\-eo").should eq(4) }
    assert { "hello world\\r\\n".count("\\").should eq(2) }
    assert { "hello world\\r\\n".count("\\A").should eq(0) }
    assert { "hello world\\r\\n".count("X-\\w").should eq(3) }
    assert { "aabbcc".count('a').should eq(2) }
    assert { "aabbcc".count { |c| ['a', 'b'].includes?(c) }.should eq(4) }
  end

  describe "squeeze" do
    assert { "aaabbbccc".squeeze { |c| ['a', 'b'].includes?(c) }.should eq("abccc") }
    assert { "aaabbbccc".squeeze { |c| ['a', 'c'].includes?(c) }.should eq("abbbc") }
    assert { "a       bbb".squeeze.should eq("a b") }
    assert { "a    bbb".squeeze(' ').should eq("a bbb") }
    assert { "aaabbbcccddd".squeeze("b-d").should eq("aaabcd") }
  end

  describe "ljust" do
    assert { "123".ljust(2).should eq("123") }
    assert { "123".ljust(5).should eq("123  ") }
    assert { "12".ljust(7, '-').should eq("12-----") }
    assert { "12".ljust(7, 'あ').should eq("12あああああ") }
  end

  describe "rjust" do
    assert { "123".rjust(2).should eq("123") }
    assert { "123".rjust(5).should eq("  123") }
    assert { "12".rjust(7, '-').should eq("-----12") }
    assert { "12".rjust(7, 'あ').should eq("あああああ12") }
  end

  describe "succ" do
    it "returns an empty string for empty strings" do
      "".succ.should eq("")
    end

    it "returns the successor by increasing the rightmost alphanumeric (digit => digit, letter => letter with same case)" do
      "abcd".succ.should eq("abce")
      "THX1138".succ.should eq("THX1139")

      "<<koala>>".succ.should eq("<<koalb>>")
      "==A??".succ.should eq("==B??")
    end

    it "increases non-alphanumerics (via ascii rules) if there are no alphanumerics" do
      "***".succ.should eq("**+")
      "**`".succ.should eq("**a")
    end

    it "increases the next best alphanumeric (jumping over non-alphanumerics) if there is a carry" do
      "dz".succ.should eq("ea")
      "HZ".succ.should eq("IA")
      "49".succ.should eq("50")

      "izz".succ.should eq("jaa")
      "IZZ".succ.should eq("JAA")
      "699".succ.should eq("700")

      "6Z99z99Z".succ.should eq("7A00a00A")

      "1999zzz".succ.should eq("2000aaa")
      "NZ/[]ZZZ9999".succ.should eq("OA/[]AAA0000")
    end

    it "adds an additional character (just left to the last increased one) if there is a carry and no character left to increase" do
      "z".succ.should eq("aa")
      "Z".succ.should eq("AA")
      "9".succ.should eq("10")

      "zz".succ.should eq("aaa")
      "ZZ".succ.should eq("AAA")
      "99".succ.should eq("100")

      "9Z99z99Z".succ.should eq("10A00a00A")

      "ZZZ9999".succ.should eq("AAAA0000")
      "/[]ZZZ9999".succ.should eq("/[]AAAA0000")
      "Z/[]ZZZ9999".succ.should eq("AA/[]AAA0000")
    end
  end

  it "uses sprintf from top-level" do
    sprintf("Hello %d world", 123).should eq("Hello 123 world")
    sprintf("Hello %d world", [123]).should eq("Hello 123 world")
  end

  it "formats floats (#1562)" do
    sprintf("%12.2f %12.2f %6.2f %.2f" % {2.0, 3.0, 4.0, 5.0}).should eq("        2.00         3.00   4.00 5.00")
  end

  it "gets each_char iterator" do
    iter = "abc".each_char
    iter.next.should eq('a')
    iter.next.should eq('b')
    iter.next.should eq('c')
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq('a')
  end

  it "gets each_char with empty string" do
    iter = "".each_char
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should be_a(Iterator::Stop)
  end

  it "cycles chars" do
    "abc".each_char.cycle.first(8).join.should eq("abcabcab")
  end

  it "gets each_byte iterator" do
    iter = "abc".each_byte
    iter.next.should eq('a'.ord)
    iter.next.should eq('b'.ord)
    iter.next.should eq('c'.ord)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq('a'.ord)
  end

  it "cycles bytes" do
    "abc".each_byte.cycle.first(8).join.should eq("9798999798999798")
  end

  it "gets lines" do
    "foo".lines.should eq(["foo"])
    "foo\nbar\nbaz\n".lines.should eq(["foo\n", "bar\n", "baz\n"])
  end

  it "gets each_line" do
    lines = [] of String
    "foo\n\nbar\nbaz\n".each_line do |line|
      lines << line
    end
    lines.should eq(["foo\n", "\n", "bar\n", "baz\n"])
  end

  it "gets each_line iterator" do
    iter = "foo\nbar\nbaz\n".each_line
    iter.next.should eq("foo\n")
    iter.next.should eq("bar\n")
    iter.next.should eq("baz\n")
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq("foo\n")
  end

  it "has yields to each_codepoint" do
    codepoints = [] of Int32
    "ab☃".each_codepoint do |codepoint|
      codepoints << codepoint
    end
    codepoints.should eq [97, 98, 9731]
  end

  it "has the each_codepoint iterator" do
    iter = "ab☃".each_codepoint
    iter.next.should eq 97
    iter.next.should eq 98
    iter.next.should eq 9731
  end

  it "has codepoints" do
    "ab☃".codepoints.should eq [97, 98, 9731]
  end

  it "gets size of \0 string" do
    "\0\0".size.should eq(2)
  end

  describe "char_index_to_byte_index" do
    it "with ascii" do
      "foo".char_index_to_byte_index(0).should eq(0)
      "foo".char_index_to_byte_index(1).should eq(1)
      "foo".char_index_to_byte_index(2).should eq(2)
      "foo".char_index_to_byte_index(3).should eq(3)
      "foo".char_index_to_byte_index(4).should be_nil
    end

    it "with utf-8" do
      "これ".char_index_to_byte_index(0).should eq(0)
      "これ".char_index_to_byte_index(1).should eq(3)
      "これ".char_index_to_byte_index(2).should eq(6)
      "これ".char_index_to_byte_index(3).should be_nil
    end
  end

  describe "byte_index_to_char_index" do
    it "with ascii" do
      "foo".byte_index_to_char_index(0).should eq(0)
      "foo".byte_index_to_char_index(1).should eq(1)
      "foo".byte_index_to_char_index(2).should eq(2)
      "foo".byte_index_to_char_index(3).should eq(3)
      "foo".byte_index_to_char_index(4).should be_nil
    end

    it "with utf-8" do
      "これ".byte_index_to_char_index(0).should eq(0)
      "これ".byte_index_to_char_index(3).should eq(1)
      "これ".byte_index_to_char_index(6).should eq(2)
      "これ".byte_index_to_char_index(7).should be_nil
      "これ".byte_index_to_char_index(1).should be_nil
    end
  end

  context "%" do
    it "substitutes one placeholder" do
      res = "change %{this}" % {"this": "nothing"}
      res.should eq "change nothing"
    end

    it "substitutes multiple placeholder" do
      res = "change %{this} and %{more}" % {"this": "nothing", "more": "something"}
      res.should eq "change nothing and something"
    end

    it "throws an error when the key is not found" do
      expect_raises KeyError do
        "change %{this}" % {"that": "wrong key"}
      end
    end

    it "raises if expecting hash but not given" do
      expect_raises(ArgumentError, "one hash required") do
        "change %{this}" % "this"
      end
    end

    it "raises on unbalanced curly" do
      expect_raises(ArgumentError, "malformed name - unmatched parenthesis") do
        "change %{this" % {"this": 1}
      end
    end

    it "applies formatting to %<...> placeholder" do
      res = "change %<this>.2f" % {"this": 23.456}
      res.should eq "change 23.46"
    end
  end

  it "raises if string capacity is negative" do
    expect_raises(ArgumentError, "negative capacity") do
      String.new(-1) { |buf| {0, 0} }
    end
  end

  it "raises if capacity too big on new with UInt32::MAX" do
    expect_raises(ArgumentError, "capacity too big") do
      String.new(UInt32::MAX) { {0, 0} }
    end
  end

  it "raises if capacity too big on new with UInt64::MAX" do
    expect_raises(ArgumentError, "capacity too big") do
      String.new(UInt64::MAX) { {0, 0} }
    end
  end

  it "compares non-case insensitive" do
    "fo".compare("foo").should eq(-1)
    "foo".compare("fo").should eq(1)
    "foo".compare("foo").should eq(0)
    "foo".compare("fox").should eq(-1)
    "fox".compare("foo").should eq(1)
    "foo".compare("Foo").should eq(1)
  end

  it "compares case insensitive" do
    "fo".compare("FOO", case_insensitive: true).should eq(-1)
    "foo".compare("FO", case_insensitive: true).should eq(1)
    "foo".compare("FOO", case_insensitive: true).should eq(0)
    "foo".compare("FOX", case_insensitive: true).should eq(-1)
    "fox".compare("FOO", case_insensitive: true).should eq(1)
    "fo\u{0000}".compare("FO", case_insensitive: true).should eq(1)
  end

  it "raises if String.build negative capacity" do
    expect_raises(ArgumentError, "negative capacity") do
      String.build(-1) { }
    end
  end

  it "raises if String.build capacity too big" do
    expect_raises(ArgumentError, "capacity too big") do
      String.build(UInt32::MAX) { }
    end
  end

  describe "encode" do
    it "encodes" do
      bytes = "Hello".encode("UCS-2LE")
      bytes.to_a.should eq([72, 0, 101, 0, 108, 0, 108, 0, 111, 0])
    end

    it "raises if wrong encoding" do
      expect_raises ArgumentError, "invalid encoding: FOO" do
        "Hello".encode("FOO")
      end
    end

    it "raises if wrong encoding with skip" do
      expect_raises ArgumentError, "invalid encoding: FOO" do
        "Hello".encode("FOO", invalid: :skip)
      end
    end

    it "raises if illegal byte sequence" do
      expect_raises ArgumentError, "invalid multibyte sequence" do
        "ñ".encode("GB2312")
      end
    end

    it "doesn't raise on invalid byte sequence" do
      "好ñ是".encode("GB2312", invalid: :skip).to_a.should eq([186, 195, 202, 199])
    end

    it "raises if incomplete byte sequence" do
      expect_raises ArgumentError, "incomplete multibyte sequence" do
        "好".byte_slice(0, 1).encode("GB2312")
      end
    end

    it "doesn't raise if incomplete byte sequence" do
      ("好".byte_slice(0, 1) + "是").encode("GB2312", invalid: :skip).to_a.should eq([202, 199])
    end

    it "decodes" do
      bytes = "Hello".encode("UTF-16LE")
      String.new(bytes, "UTF-16LE").should eq("Hello")
    end

    it "decodes with skip" do
      bytes = UInt8[186, 195, 140, 202, 199]
      bytes = Slice.new(bytes.to_unsafe, bytes.size)
      String.new(bytes, "GB2312", invalid: :skip).should eq("好是")
    end
  end
end
