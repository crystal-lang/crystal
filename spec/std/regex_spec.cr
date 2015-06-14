require "spec"

describe "Regex" do
  it "matches with =~ and captures" do
    ("fooba" =~ /f(o+)(bar?)/).should eq(0)
    $~.length.should eq(2)
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
    $~.length.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  it "raises if outside match range with []" do
    "foo" =~ /foo/
    expect_raises(IndexOutOfBounds) { $1 }
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

  describe "MatchData#[]" do
    it "raises if outside match range with []" do
      "foo" =~ /foo/
      expect_raises(IndexOutOfBounds) { $~[1] }
    end

    it "capture named group" do
      ("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/).should eq(0)
      $~["g1"].should eq("oo")
      $~["g2"].should eq("ba")
    end

    it "capture empty group" do
      ("foo" =~ /(?<g1>.*)foo/).should eq(0)
      $~["g1"].should eq("")
    end

    it "raises exception when named group doesn't exist" do
      ("foo" =~ /foo/).should eq(0)
      expect_raises(ArgumentError) { $~["group"] }
    end
  end

  describe "MatchData#[]?" do
    it "returns nil if outside match range with []" do
      "foo" =~ /foo/
      $~[1]?.should be_nil
    end

    it "capture named group" do
      ("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/).should eq(0)
      $~["g1"]?.should eq("oo")
      $~["g2"]?.should eq("ba")
    end

    it "capture empty group" do
      ("foo" =~ /(?<g1>.*)foo/).should eq(0)
      $~["g1"]?.should eq("")
    end

    it "returns nil exception when named group doesn't exist" do
      ("foo" =~ /foo/).should eq(0)
      $~["group"]?.should be_nil
    end
  end

  it "matches multiline" do
    ("foo\n<bar\n>baz" =~ /<bar.*?>/).should be_nil
    ("foo\n<bar\n>baz" =~ /<bar.*?>/m).should eq(4)
  end

  it "matches ignore case" do
    ("HeLlO" =~ /hello/).should be_nil
    ("HeLlO" =~ /hello/i).should eq(0)
  end

  it "does to_s" do
    /foo/.to_s.should eq("/foo/")
    /foo/imx.to_s.should eq("/foo/imx")

    /f(o)(x)/.match("the fox").to_s.should eq(%(#<MatchData "fox" 1:"o" 2:"x">))
    /f(?<lettero>o)(?<letterx>x)/.match("the fox").to_s.should eq(%(#<MatchData "fox" lettero:"o" letterx:"x">))
    /fox/.match("the fox").to_s.should eq(%(#<MatchData "fox">))
    /f(o)(x)/.match("the fox").inspect.should eq(%(#<MatchData "fox" 1:"o" 2:"x">))
    /fox/.match("the fox").inspect.should eq(%(#<MatchData "fox">))
  end

  it "does inspect" do
    /foo/.inspect.should eq("/foo/")
  end

  it "raises exception with invalid regex" do
    expect_raises(ArgumentError) { Regex.new("+") }
  end

  it "escapes" do
    Regex.escape(" .\\+*?[^]$(){}=!<>|:-hello").should eq("\\ \\.\\\\\\+\\*\\?\\[\\^\\]\\$\\(\\)\\{\\}\\=\\!\\<\\>\\|\\:\\-hello")
  end

  it "doesn't crash when PCRE tries to free some memory (#771)" do
    expect_raises(ArgumentError) { Regex.new("foo)") }
  end

  it "compare to other instances" do
    Regex.new("foo").should eq(Regex.new("foo"))
    Regex.new("foo").should_not eq(Regex.new("bar"))
  end
end
