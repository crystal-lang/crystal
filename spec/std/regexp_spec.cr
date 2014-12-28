require "spec"

describe "Regex" do
  it "matches with =~ and captures" do
    ("fooba" =~ /f(o+)(bar?)/).should eq(0)
    $~.length.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
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
    /f(o)(x)/.match("fox").to_s.should eq(%(MatchData("fox" ["o", "x"])))
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
end
