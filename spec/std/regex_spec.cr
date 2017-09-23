require "spec"

describe "Regex" do
  it "compare to other instances" do
    Regex.new("foo").should eq(Regex.new("foo"))
    Regex.new("foo").should_not eq(Regex.new("bar"))
  end

  it "does =~" do
    (/foo/ =~ "bar foo baz").should eq(4)
    $~.group_size.should eq(0)
  end

  it "does inspect" do
    /foo/.inspect.should eq("/foo/")
    /foo/.inspect.should eq("/foo/")
    /foo/imx.inspect.should eq("/foo/imx")
  end

  it "does to_s" do
    /foo/.to_s.should eq("(?-imsx:foo)")
    /foo/im.to_s.should eq("(?ims-x:foo)")
    /foo/imx.to_s.should eq("(?imsx-:foo)")

    "Crystal".match(/(?<bar>C)#{/(?<foo>R)/i}/).should be_truthy
    "Crystal".match(/(?<bar>C)#{/(?<foo>R)/}/i).should be_falsey

    md = "Crystal".match(/(?<bar>.)#{/(?<foo>.)/}/).not_nil!
    md[0].should eq("Cr")
    md["bar"].should eq("C")
    md["foo"].should eq("r")
  end

  it "does inspect with slash" do
    %r(/).inspect.should eq("/\\//")
  end

  it "does to_s with slash" do
    %r(/).to_s.should eq("(?-imsx:\\/)")
  end

  it "doesn't crash when PCRE tries to free some memory (#771)" do
    expect_raises(ArgumentError) { Regex.new("foo)") }
  end

  it "escapes" do
    Regex.escape(" .\\+*?[^]$(){}=!<>|:-hello").should eq("\\ \\.\\\\\\+\\*\\?\\[\\^\\]\\$\\(\\)\\{\\}\\=\\!\\<\\>\\|\\:\\-hello")
  end

  it "matches ignore case" do
    ("HeLlO" =~ /hello/).should be_nil
    ("HeLlO" =~ /hello/i).should eq(0)
  end

  it "matches lines beginnings on ^ in multiline mode" do
    ("foo\nbar" =~ /^bar/).should be_nil
    ("foo\nbar" =~ /^bar/m).should eq(4)
  end

  it "matches multiline" do
    ("foo\n<bar\n>baz" =~ /<bar.*?>/).should be_nil
    ("foo\n<bar\n>baz" =~ /<bar.*?>/m).should eq(4)
  end

  it "matches with =~ and captures" do
    ("fooba" =~ /f(o+)(bar?)/).should eq(0)
    $~.group_size.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  it "matches with =~ and gets utf-8 codepoint index" do
    index = "こんに" =~ /ん/
    index.should eq(1)
  end

  it "matches with === and captures" do
    "foo" =~ /foo/
    (/f(o+)(bar?)/ === "fooba").should be_true
    $~.group_size.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  describe "name_table" do
    it "is a map of capture group number to name" do
      table = (/(?<date> (?<year>(\d\d)?\d\d) - (?<month>\d\d) - (?<day>\d\d) )/x).name_table
      table[1].should eq("date")
      table[2].should eq("year")
      table[3]?.should be_nil
      table[4].should eq("month")
      table[5].should eq("day")
    end
  end

  it "raises exception with invalid regex" do
    expect_raises(ArgumentError) { Regex.new("+") }
  end

  it "raises if outside match range with []" do
    "foo" =~ /foo/
    expect_raises(IndexError) { $1 }
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

  it "dups" do
    regex = /foo/
    regex.dup.should be(regex)
  end

  it "clones" do
    regex = /foo/
    regex.clone.should be(regex)
  end
end
