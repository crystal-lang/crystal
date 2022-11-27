require "./spec_helper"

describe "Regex" do
  describe ".new" do
    it "doesn't crash when PCRE tries to free some memory (#771)" do
      expect_raises(ArgumentError) { Regex.new("foo)") }
    end

    it "raises exception with invalid regex" do
      expect_raises(ArgumentError) { Regex.new("+") }
    end
  end

  describe "#match" do
    it "returns matchdata" do
      md = "Crystal".match(/(?<bar>.)#{/(?<foo>.)/}/).not_nil!
      md[0].should eq("Cr")
      md["bar"].should eq("C")
      md["foo"].should eq("r")
    end

    it "matches unicode char against [[:alnum:]] (#4704)" do
      /[[:alnum:]]/x.match("à").should_not be_nil
    end
  end

  describe "#===" do
    it "basic" do
      (/f(o+)(bar?)/ === "fooba").should be_true
      (/f(o+)(bar?)/ === "pooba").should be_false
    end

    it "assigns captures" do
      (/f(o+)(bar?)/ === "fooba").should be_true
      $~.group_size.should eq(2)
      $1.should eq("oo")
      $2.should eq("ba")
    end
  end

  describe "#=~" do
    it "returns match index" do
      (/foo/ =~ "bar foo baz").should eq(4)
      $~.group_size.should eq(0)
    end

    it "ignore case" do
      ("HeLlO" =~ /hello/).should be_nil
      ("HeLlO" =~ /hello/i).should eq(0)
    end

    it "multiline anchor" do
      ("foo\nbar" =~ /^bar/).should be_nil
      ("foo\nbar" =~ /^bar/m).should eq(4)
    end

    it "multiline span" do
      ("foo\n<bar\n>baz" =~ /<bar.*?>/).should be_nil
      ("foo\n<bar\n>baz" =~ /<bar.*?>/m).should eq(4)
    end

    it "matches unicode char against [[:print:]] (#11262)" do
      ("\n☃" =~ /[[:print:]]/).should eq(1)
    end

    it "assigns captures" do
      ("fooba" =~ /f(o+)(bar?)/).should eq(0)
      $~.group_size.should eq(2)
      $1.should eq("oo")
      $2.should eq("ba")
    end

    it "utf-8 support" do
      ("こんに" =~ /ん/).should eq(1)
    end

    it "raises if outside match range with []" do
      "foo" =~ /foo/
      expect_raises(IndexError) { $1 }
    end
  end

  describe "#match_at_byte_index" do
  end

  describe "#matches?" do
    it "matches but create no MatchData" do
      /f(o+)(bar?)/.matches?("fooba").should be_true
      /f(o+)(bar?)/.matches?("barfo").should be_false
    end

    it "can specify initial position of matching" do
      /f(o+)(bar?)/.matches?("fooba", 1).should be_false
    end

    it "matches a large single line string" do
      LibPCRE.config LibPCRE::CONFIG_JIT, out jit_enabled
      pending! "PCRE JIT mode not available." unless 1 == jit_enabled

      str = File.read(datapath("large_single_line_string.txt"))
      str.matches?(/^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/).should be_false
    end
  end

  describe "#matches_at_byte_index?" do
  end

  describe "#name_table" do
    it "is a map of capture group number to name" do
      table = (/(?<date> (?<year>(\d\d)?\d\d) - (?<month>\d\d) - (?<day>\d\d) )/x).name_table
      table[1].should eq("date")
      table[2].should eq("year")
      table[3]?.should be_nil
      table[4].should eq("month")
      table[5].should eq("day")
    end
  end

  it "#capture_count" do
    /(?:.)/x.capture_count.should eq(0)
    /(?<foo>.+)/.capture_count.should eq(1)
    /(.)?/x.capture_count.should eq(1)
    /(.)|(.)/x.capture_count.should eq(2)
  end

  describe "#inspect" do
    it "with options" do
      /foo/.inspect.should eq("/foo/")
      /foo/.inspect.should eq("/foo/")
      /foo/imx.inspect.should eq("/foo/imx")
    end

    it "with slash" do
      %r(/).inspect.should eq("/\\//")
      %r(\/).inspect.should eq("/\\//")
    end
  end

  describe "#to_s" do
    it "with options" do
      /foo/.to_s.should eq("(?-imsx:foo)")
      /foo/im.to_s.should eq("(?ims-x:foo)")
      /foo/imx.to_s.should eq("(?imsx-:foo)")
    end

    it "escapes" do
      "Crystal".match(/(?<bar>C)#{/(?<foo>R)/i}/).should be_truthy
      "Crystal".match(/(?<bar>C)#{/(?<foo>R)/}/i).should be_falsey
    end

    it "with slash" do
      %r(/).to_s.should eq("(?-imsx:\\/)")
      %r(\/).to_s.should eq("(?-imsx:\\/)")
    end
  end

  it "#==" do
    regex = Regex.new("foo", Regex::Options::IGNORE_CASE)
    (regex == Regex.new("foo", Regex::Options::IGNORE_CASE)).should be_true
    (regex == Regex.new("foo")).should be_false
    (regex == Regex.new("bar", Regex::Options::IGNORE_CASE)).should be_false
    (regex == Regex.new("bar")).should be_false
  end

  it "#hash" do
    hash = Regex.new("foo", Regex::Options::IGNORE_CASE).hash
    hash.should eq(Regex.new("foo", Regex::Options::IGNORE_CASE).hash)
    hash.should_not eq(Regex.new("foo").hash)
    hash.should_not eq(Regex.new("bar", Regex::Options::IGNORE_CASE).hash)
    hash.should_not eq(Regex.new("bar").hash)
  end

  it "#dup" do
    regex = /foo/
    regex.dup.should be(regex)
  end

  it "#clone" do
    regex = /foo/
    regex.clone.should be(regex)
  end

  describe ".needs_escape?" do
    it "Char" do
      Regex.needs_escape?('*').should be_true
      Regex.needs_escape?('|').should be_true
      Regex.needs_escape?('@').should be_false
    end

    it "String" do
      Regex.needs_escape?("10$").should be_true
      Regex.needs_escape?("foo").should be_false
    end
  end

  it ".escape" do
    Regex.escape(" .\\+*?[^]$(){}=!<>|:-hello").should eq("\\ \\.\\\\\\+\\*\\?\\[\\^\\]\\$\\(\\)\\{\\}\\=\\!\\<\\>\\|\\:\\-hello")
  end

  describe ".union" do
    it "constructs a Regex that matches things any of its arguments match" do
      re = Regex.union(/skiing/i, "sledding")
      re.match("Skiing").not_nil![0].should eq "Skiing"
      re.match("sledding").not_nil![0].should eq "sledding"
    end

    it "returns a regular expression that will match passed arguments" do
      Regex.union("penzance").should eq /penzance/
      Regex.union("skiing", "sledding").should eq /skiing|sledding/
      Regex.union(/dogs/, /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
    end

    it "quotes any string arguments" do
      Regex.union("n", ".").should eq /n|\./
    end

    it "returns a Regex with an Array(String) with special characters" do
      Regex.union(["+", "-"]).should eq /\+|\-/
    end

    it "accepts a single Array(String | Regex) argument" do
      Regex.union(["skiing", "sledding"]).should eq /skiing|sledding/
      Regex.union([/dogs/, /cats/i]).should eq /(?-imsx:dogs)|(?i-msx:cats)/
      (/dogs/ + /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
    end

    it "accepts a single Tuple(String | Regex) argument" do
      Regex.union({"skiing", "sledding"}).should eq /skiing|sledding/
      Regex.union({/dogs/, /cats/i}).should eq /(?-imsx:dogs)|(?i-msx:cats)/
      (/dogs/ + /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
    end

    it "combines Regex objects in the same way as Regex#+" do
      Regex.union(/skiing/i, /sledding/).should eq(/skiing/i + /sledding/)
    end
  end

  it "#+" do
    (/dogs/ + /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
  end

  it ".error?" do
    Regex.error?("(foo|bar)").should be_nil
    Regex.error?("(foo|bar").should eq "missing ) at 8"
  end
end
