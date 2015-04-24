require "spec"

describe "Regex" do
  it "matches with =~ and captures" do
    expect(("fooba" =~ /f(o+)(bar?)/)).to eq(0)
    expect($~.length).to eq(2)
    expect($1).to eq("oo")
    expect($2).to eq("ba")
  end

  it "matches with =~ and gets utf-8 codepoint index" do
    index = "こんに" =~ /ん/
    expect(index).to eq(1)
  end

  it "matches with === and captures" do
    "foo" =~ /foo/
    expect((/f(o+)(bar?)/ === "fooba")).to be_true
    expect($~.length).to eq(2)
    expect($1).to eq("oo")
    expect($2).to eq("ba")
  end

  it "raises if outside match range with []" do
    "foo" =~ /foo/
    expect_raises(IndexOutOfBounds) { $1 }
  end

  describe "MatchData#[]" do
    it "raises if outside match range with []" do
      "foo" =~ /foo/
      expect_raises(IndexOutOfBounds) { $~[1] }
    end

    it "capture named group" do
      expect(("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/)).to eq(0)
      expect($~["g1"]).to eq("oo")
      expect($~["g2"]).to eq("ba")
    end

    it "capture empty group" do
      expect(("foo" =~ /(?<g1>.*)foo/)).to eq(0)
      expect($~["g1"]).to eq("")
    end

    it "raises exception when named group doesn't exist" do
      expect(("foo" =~ /foo/)).to eq(0)
      expect_raises(ArgumentError) { $~["group"] }
    end
  end

  describe "MatchData#[]?" do
    it "returns nil if outside match range with []" do
      "foo" =~ /foo/
      expect($~[1]?).to be_nil
    end

    it "capture named group" do
      expect(("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/)).to eq(0)
      expect($~["g1"]?).to eq("oo")
      expect($~["g2"]?).to eq("ba")
    end

    it "capture empty group" do
      expect(("foo" =~ /(?<g1>.*)foo/)).to eq(0)
      expect($~["g1"]?).to eq("")
    end

    it "returns nil exception when named group doesn't exist" do
      expect(("foo" =~ /foo/)).to eq(0)
      expect($~["group"]?).to be_nil
    end
  end

  it "matches multiline" do
    expect(("foo\n<bar\n>baz" =~ /<bar.*?>/)).to be_nil
    expect(("foo\n<bar\n>baz" =~ /<bar.*?>/m)).to eq(4)
  end

  it "matches ignore case" do
    expect(("HeLlO" =~ /hello/)).to be_nil
    expect(("HeLlO" =~ /hello/i)).to eq(0)
  end

  it "does to_s" do
    expect(/foo/.to_s).to eq("/foo/")
    expect(/f(o)(x)/.match("the fox").to_s).to eq(%(#<MatchData "fox" 1:"o" 2:"x">))
    expect(/fox/.match("the fox").to_s).to eq(%(#<MatchData "fox">))
    expect(/f(o)(x)/.match("the fox").inspect).to eq(%(#<MatchData "fox" 1:"o" 2:"x">))
    expect(/fox/.match("the fox").inspect).to eq(%(#<MatchData "fox">))
  end

  it "does inspect" do
    expect(/foo/.inspect).to eq("/foo/")
  end

  it "raises exception with invalid regex" do
    expect_raises(ArgumentError) { Regex.new("+") }
  end

  it "escapes" do
    expect(Regex.escape(" .\\+*?[^]$(){}=!<>|:-hello")).to eq("\\ \\.\\\\\\+\\*\\?\\[\\^\\]\\$\\(\\)\\{\\}\\=\\!\\<\\>\\|\\:\\-hello")
  end
end
