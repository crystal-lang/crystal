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

  describe "to_a" do
    it "produces an array containing the full and group matches" do
      str = "Crystal is great!"
      re = /([A-Z]*).* (.*) .*?(?<vowels>[aeiou]+)t!/
      md = re.match(str).not_nil!
      md.to_a.should eq(["Crystal is great!", "C", "is", "ea"])
    end

    it "includes nil for optional groups that don't match" do
      str = "Crystal is great!"
      re = /([A-Z][^ ]*) is (not ?)?.*([0-9])*.*(.)$/
      md = re.match(str).not_nil!
      md.to_a.should eq(["Crystal is great!", "Crystal", nil, nil, "!"])
    end

    it "contains only the full match if there are no groups" do
      str = "Crystal is great!"
      re = /[A-Z][^ ]* is (?:not ?)?.*$/
      md = re.match(str).not_nil!
      md.to_a.should eq(["Crystal is great!"])
    end
  end

  describe "to_h" do
    it "produces a hash containing the key-value pairs for named group and match" do
      str = "Regex is super fun!"
      re = /(?<subject>[a-z]+) (?<predicate>(?<verb>[a-z]+) (?:(?<adjective>[a-z]+) )?(?<noun>[a-z]+)(?<extra>.+)?)/i
      md = re.match(str).not_nil!
      md.to_h.should eq({"subject" => "Regex", "predicate" => "is super fun!", "verb" => "is", "adjective" => "super", "noun" => "fun", "extra" => "!"})
    end

    it "produces keys with nil values when the given named group has no match" do
      str = "Crystal is fast"
      re = /(?<subject>[a-z]+) (?<predicate>(?<verb>[a-z]+) (?:(?<adjective>[a-z]+) )?(?<noun>[a-z]+)(?<extra>.+)?)/i
      md = re.match(str).not_nil!
      md.to_h.should eq({"subject" => "Crystal", "predicate" => "is fast", "verb" => "is", "adjective" => nil, "noun" => "fast", "extra" => nil})
    end

    it "produces an empty hash when there are no named groups" do
      str = "Crystal is great!"
      re = /([A-Z][^ ]*) is (not ?)?.*([0-9])*.*(.)$/
      md = re.match(str).not_nil!
      md.to_h.should eq({} of String => (String | Nil))
    end
  end

  describe "group_names" do
    it "returns an array of group names" do
      str = "Regex is super fun!"
      re = /(?<subject>[a-z]+) (?<predicate>(?<verb>[a-z]+) (?:(?<adjective>[a-z]+) )?(?<noun>[a-z]+)(?<extra>.+)?)/i
      md = re.match(str).not_nil!
      md.group_names.should eq(["subject", "predicate", "verb", "adjective", "noun", "extra"])
    end

    it "returns full list of group names even if some don't match" do
      str = "Crystal is fast"
      re = /(?<subject>[a-z]+) (?<predicate>(?<verb>[a-z]+) (?:(?<adjective>[a-z]+) )?(?<noun>[a-z]+)(?<extra>.+)?)/i
      md = re.match(str).not_nil!
      md.group_names.should eq(["subject", "predicate", "verb", "adjective", "noun", "extra"])
    end

    it "returns an empty array if there are no named groups" do
      str = "Crystal is great!"
      re = /([A-Z][^ ]*) is (not ?)?.*([0-9])*.*(.)$/
      md = re.match(str).not_nil!
      md.group_names.should eq([] of String)
    end
  end

  describe "matched_named_groups" do
    it "returns an array of group names that have matches" do
      str = "Regex is super fun!"
      re = /(?<subject>[a-z]+) (?<predicate>(?<verb>[a-z]+) (?:(?<adjective>[a-z]+) )?(?<noun>[a-z]+)(?<extra>.*)?$)/i
      md = re.match(str).not_nil!
      md.matched_group_names.should eq(["subject", "predicate", "verb", "adjective", "noun", "extra"])
    end

    it "returns only the group names that have matches" do
      str = "Crystal is fast"
      re = /(?<subject>[a-z]+) (?<predicate>(?<verb>[a-z]+) (?:(?<adjective>[a-z]+) )?(?<noun>[a-z]+)(?<extra>.*)?$)/i
      md = re.match(str).not_nil!
      md.matched_group_names.should eq(["subject", "predicate", "verb", "noun", "extra"])
    end

    it "returns an empty array if there are no named groups" do
      str = "Crystal is great!"
      re = /([A-Z][^ ]*) is (not ?)?.*([0-9])*.*(.)$/
      md = re.match(str).not_nil!
      md.matched_group_names.should eq([] of String)
    end
  end
end
