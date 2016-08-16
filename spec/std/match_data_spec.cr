require "spec"

describe "Regex::MatchData" do
  it "does inspect" do
    /f(o)(x)/.match("the fox").inspect.should eq(%(#<Regex::MatchData "fox" 1:"o" 2:"x">))
    /f(o)(x)?/.match("the fort").inspect.should eq(%(#<Regex::MatchData "fo" 1:"o" 2:nil>))
    /fox/.match("the fox").inspect.should eq(%(#<Regex::MatchData "fox">))
  end

  it "does to_s" do
    /f(o)(x)/.match("the fox").to_s.should eq(%(#<Regex::MatchData "fox" 1:"o" 2:"x">))
    /f(?<lettero>o)(?<letterx>x)/.match("the fox").to_s.should eq(%(#<Regex::MatchData "fox" lettero:"o" letterx:"x">))
    /fox/.match("the fox").to_s.should eq(%(#<Regex::MatchData "fox">))
  end

  describe "#[]" do
    it "captures empty group" do
      ("foo" =~ /(?<g1>z?)foo/).should eq(0)
      $~[1].should eq("")
      $~["g1"].should eq("")
    end

    it "capture named group" do
      ("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/).should eq(0)
      $~["g1"].should eq("oo")
      $~["g2"].should eq("ba")
    end

    it "raises exception on optional empty group" do
      ("foo" =~ /(?<g1>z)?foo/).should eq(0)
      expect_raises(Exception) { $~[1] }
      expect_raises(Exception) { $~["g1"] }
    end

    it "raises exception when named group doesn't exist" do
      ("foo" =~ /foo/).should eq(0)
      expect_raises(ArgumentError) { $~["group"] }
    end

    it "raises if outside match range with []" do
      "foo" =~ /foo/
      expect_raises(IndexError) { $~[1] }
    end
  end

  describe "#[]?" do
    it "capture empty group" do
      ("foo" =~ /(?<g1>z?)foo/).should eq(0)
      $~[1]?.should eq("")
      $~["g1"]?.should eq("")
    end

    it "capture optional empty group" do
      ("foo" =~ /(?<g1>z)?foo/).should eq(0)
      $~[1]?.should be_nil
      $~["g1"]?.should be_nil
    end

    it "capture named group" do
      ("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/).should eq(0)
      $~["g1"]?.should eq("oo")
      $~["g2"]?.should eq("ba")
    end

    it "returns nil exception when named group doesn't exist" do
      ("foo" =~ /foo/).should eq(0)
      $~["group"]?.should be_nil
    end

    it "returns nil if outside match range with []" do
      "foo" =~ /foo/
      $~[1]?.should be_nil
    end
  end

  describe "#post_match" do
    it "returns an empty string when there's nothing after" do
      "Crystal".match(/ystal/).not_nil!.post_match.should eq ""
    end

    it "returns the part of the string after the match" do
      "Crystal".match(/yst/).not_nil!.post_match.should eq "al"
    end

    it "works with unicode" do
      "há日本語".match(/本/).not_nil!.post_match.should eq "語"
    end
  end

  describe "#pre_match" do
    it "returns an empty string when there's nothing before" do
      "Crystal".match(/Cryst/).not_nil!.pre_match.should eq ""
    end

    it "returns the part of the string before the match" do
      "Crystal".match(/yst/).not_nil!.pre_match.should eq "Cr"
    end

    it "works with unicode" do
      "há日本語".match(/本/).not_nil!.pre_match.should eq "há日"
    end
  end
end
