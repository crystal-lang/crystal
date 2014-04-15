#!/usr/bin/env bin/crystal --run
require "spec"

describe "String" do
  describe "[]" do
    it "gets with positive index" do
      "hello!"[1].should eq('e')
    end

    it "gets with negative index" do
      "hello!"[-1].should eq('!')
    end

    it "gets with inclusive range" do
      "hello!"[1 .. 4].should eq("ello")
    end

    it "gets with inclusive range with negative indices" do
      "hello!"[-5 .. -2].should eq("ello")
    end

    it "gets with exclusive range" do
      "hello!"[1 ... 4].should eq("ell")
    end

    it "gets with start and count" do
      "hello"[1, 3].should eq("ell")
    end
  end

  it "does to_i" do
    "1234".to_i.should eq(1234)
  end

  it "does to_i with base" do
    "12ab".to_i(16).should eq(4779)
  end

  it "does to_i32" do
    "1234".to_i32.should eq(1234)
  end

  it "does to_i64" do
    "1234123412341234".to_i64.should eq(1234123412341234_i64)
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

  it "compares strings: different length" do
    "foo".should_not eq("fo")
  end

  it "compares strings: same object" do
    f = "foo"
    f.should eq(f)
  end

  it "compares strings: same length, same string" do
    "foo".should eq("fo" + "o")
  end

  it "compares strings: same length, different string" do
    "foo".should_not eq("bar")
  end

  it "interpolates string" do
    foo = "<foo>"
    bar = 123
    "foo #{bar}".should eq("foo 123")
    "foo #{ bar}".should eq("foo 123")
    "#{foo} bar".should eq("<foo> bar")
  end

  it "multiplies" do
    str = "foo"
    (str * 0).should eq("")
    (str * 3).should eq("foofoofoo")
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
  end

  describe "strip" do
    assert { "  hello  \n\t\f\v\r".strip.should eq("hello") }
    assert { "hello".strip.should eq("hello") }
  end

  describe "rstrip" do
    assert { "  hello  ".rstrip.should eq("  hello") }
    assert { "hello".rstrip.should eq("hello") }
  end

  describe "lstrip" do
    assert { "  hello  ".lstrip.should eq("hello  ") }
    assert { "hello".lstrip.should eq("hello") }
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

      describe "with offset" do
        assert { "foobarbaz".index('a', 5).should eq(7) }
        assert { "foobarbaz".index('a', -4).should eq(7) }
        assert { "foo".index('g', 1).should be_nil }
        assert { "foo".index('g', -20).should be_nil }
      end
    end

    describe "by string" do
      assert { "foo bar".index("o b").should eq(2) }
      assert { "foo".index("fg").should be_nil }
      assert { "foo".index("").should eq(0) }
      assert { "foo".index("foo").should eq(0) }

      describe "with offset" do
        assert { "foobarbaz".index("ba", 4).should eq(6) }
        assert { "foobarbaz".index("ba", -5).should eq(6) }
        assert { "foo".index("ba", 1).should be_nil }
        assert { "foo".index("ba", -20).should be_nil }
      end
    end
  end

  describe "rindex" do
    describe "by char" do
      assert { "foobar".rindex('a').should eq(4) }
      assert { "foobar".rindex('g').should be_nil }

      describe "with offset" do
        assert { "faobar".rindex('a', 3).should eq(1) }
        assert { "faobarbaz".rindex('a', -3).should eq(4) }
      end
    end

    describe "by string" do
      assert { "foo baro baz".rindex("o b").should eq(7) }
      assert { "foo baro baz".rindex("fg").should be_nil }
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
      assert { "foo,bar,,baz,".split(',').should eq(["foo", "bar", "", "baz"]) }
      assert { "foo,bar,,baz".split(',').should eq(["foo", "bar", "", "baz"]) }
      assert { "foo".split(',').should eq(["foo"]) }
      assert { "foo".split(' ').should eq(["foo"]) }
      assert { "   foo".split(' ').should eq(["foo"]) }
      assert { "foo   ".split(' ').should eq(["foo"]) }
      assert { "   foo  bar".split(' ').should eq(["foo", "bar"]) }
      assert { "   foo   bar\n\t  baz   ".split(' ').should eq(["foo", "bar", "baz"]) }
      assert { "   foo   bar\n\t  baz   ".split.should eq(["foo", "bar", "baz"]) }
      assert { "   foo   bar\n\t  baz   ".split(" ").should eq(["foo", "bar", "baz"]) }
      assert { "foo,bar,baz,qux".split(',', 1).should eq(["foo,bar,baz,qux"]) }
      assert { "foo,bar,baz,qux".split(',', 3).should eq(["foo", "bar", "baz,qux"]) }
      assert { "foo,bar,baz,qux".split(',', 30).should eq(["foo", "bar", "baz", "qux"]) }
    end

    describe "by string" do
      assert { "foo:-bar:-:-baz:-".split(":-").should eq(["foo", "bar", "", "baz"]) }
      assert { "foo:-bar:-:-baz".split(":-").should eq(["foo", "bar", "", "baz"]) }
      assert { "foo".split(":-").should eq(["foo"]) }
      assert { "foo".split("").should eq(["f", "o", "o"]) }
    end
  end

  describe "starts_with?" do
    assert { "foobar".starts_with?("foo").should be_true }
    assert { "foobar".starts_with?("").should be_true }
    assert { "foobar".starts_with?("foobarbaz").should be_false }
    assert { "foobar".starts_with?("foox").should be_false }
    assert { "foobar".starts_with?('f').should be_true }
    assert { "foobar".starts_with?('g').should be_false }
  end

  describe "ends_with?" do
    assert { "foobar".ends_with?("bar").should be_true }
    assert { "foobar".ends_with?("").should be_true }
    assert { "foobar".ends_with?("foobarbaz").should be_false }
    assert { "foobar".ends_with?("xbar").should be_false }
    assert { "foobar".ends_with?('r').should be_true }
    assert { "foobar".ends_with?('x').should be_false }
  end

  describe "=~" do
    it "matches with group" do
      "foobar" =~ /(o+)ba(r?)/
      $1.should eq("oo")
      $2.should eq("r")
    end
  end

  it "deletes one char" do
    deleted = "foobar".delete('o')
    deleted.length.should eq(4)
    deleted.should eq("fbar")

    deleted = "foobar".delete('x')
    deleted.length.should eq(6)
    deleted.should eq("foobar")
  end

  it "reverses string" do
    reversed = "foobar".reverse
    reversed.length.should eq(6)
    reversed.should eq("raboof")
  end

  it "replaces char with string" do
    replaced = "foobar".replace('o', "ex")
    replaced.length.should eq(8)
    replaced.should eq("fexexbar")
  end

  it "replaces char with string depending on the char" do
    replaced = "foobar".replace do |char|
      case char
      when 'f'
        "some"
      when 'o'
        "thing"
      when 'a'
        "ex"
      else
        nil
      end
    end
    replaced.length.should eq(18)
    replaced.should eq("somethingthingbexr")
  end

  it "replaces with regex" do
    actual = "foo booor booooz".replace(/o+/) do |match|
      "#{match}#{match.length}"
    end
    actual.should eq("foo2 booo3r boooo4z")
  end

  it "dumps" do
    "\" \\ \f \n \r \t \v cool \x1 \x1F \x79".dump.should eq("\\\" \\ \\f \\n \\r \\t \\v cool \\x01 \\x1F y")
  end

  it "inspects" do
    "\" \\ \f \n \r \t \v cool".inspect.should eq("\"\\\" \\ \\f \\n \\r \\t \\v cool\"")
  end

  it "does *" do
    str = "foo" * 10
    str.length.should eq(30)
    str.should eq("foofoofoofoofoofoofoofoofoofoo")
  end

  it "does +" do
    str = "foo" + "bar"
    str.length.should eq(6)
    str.should eq("foobar")
  end

  it "does %" do
    ("foo" % 1).should        eq("foo")
    ("foo %d" % 1).should     eq("foo 1")
    ("%d" % 123).should       eq("123")
    ("%+d" % 123).should      eq("+123")
    ("%+d" % -123).should     eq("-123")
    ("% d" % 123).should      eq(" 123")
    ("%20d" % 123).should     eq("                 123")
    ("%+20d" % 123).should    eq("                +123")
    ("%+20d" % -123).should   eq("                -123")
    ("% 20d" % 123).should    eq("                 123")
    ("%020d" % 123).should    eq("00000000000000000123")
    ("%+020d" % 123).should   eq("+0000000000000000123")
    ("% 020d" % 123).should   eq(" 0000000000000000123")
    ("%-d" % 123).should      eq("123")
    ("%-20d" % 123).should    eq("123                 ")
    ("%-+20d" % 123).should   eq("+123                ")
    ("%-+20d" % -123).should  eq("-123                ")
    ("%- 20d" % 123).should   eq(" 123                ")
    ("%s" % 'a').should       eq("a")
    ("%-s" % 'a').should      eq("a")
    ("%20s" % 'a').should     eq("                   a")
    ("%20s" % 'a').should     eq("                   a")
    ("%-20s" % 'a').should    eq("a                   ")

    ("%%%d" % 1).should eq("%1")
    ("foo %d bar %s baz %d goo" % [1, "hello", 2]).should eq("foo 1 bar hello baz 2 goo")
  end

  it "escapes chars" do
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
    "\3"[0].should eq(3)
    "\23"[0].should eq((2 * 8) + 3)
    "\123"[0].should eq((1 * 8 * 8) + (2 * 8) + 3)
    "\033"[0].should eq((3 * 8) + 3)
    "\033a"[1].should eq('a')
  end

  pending "escapes with hex" do
    "\x12"[0].should eq(1 * 16 + 2)
    "\xA"[0].should eq(10)
    "\xAB"[0].should eq(10 * 16 + 11)
    "\xAB1"[1].should eq('1'.ord)
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
    s.length.should eq(3)
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
    "über".tr("ü","u").should eq("uber")
  end
end
