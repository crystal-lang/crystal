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

  it "does pretty_print" do
    /f(o)(x)?/.match("the fo").pretty_inspect.should eq(%(#<Regex::MatchData "fo" 1:"o" 2:nil>))

    expected = <<-REGEX
      #<Regex::MatchData
       "foooo"
       first:"f"
       second:"oooo"
       third:"ooo"
       fourth:"oo"
       fifth:"o">
      REGEX

    /(?<first>f)(?<second>o(?<third>o(?<fourth>o(?<fifth>o))))/.match("fooooo").pretty_inspect.should eq(expected)
  end

  it "does size" do
    "Crystal".match(/[p-s]/).not_nil!.size.should eq(1)
    "Crystal".match(/r(ys)/).not_nil!.size.should eq(2)
    "Crystal".match(/r(ys)(?<ok>ta)/).not_nil!.size.should eq(3)
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

    it "can use negative index" do
      "foo" =~ /(f)(oo)/
      $~[-1].should eq("oo")
      $~[-2].should eq("f")
      $~[-3].should eq("foo")
      expect_raises(IndexError, "Invalid capture group index: -4") { $~[-4] }
    end

    it "raises exception when named group doesn't exist" do
      ("foo" =~ /foo/).should eq(0)
      expect_raises(KeyError, "Capture group 'group' does not exist") { $~["group"] }
    end

    it "raises exception on optional empty group" do
      ("foo" =~ /(?<g1>z)?foo/).should eq(0)
      expect_raises(IndexError, "Capture group 1 was not matched") { $~[1] }
      expect_raises(KeyError, "Capture group 'g1' was not matched") { $~["g1"] }
    end

    it "raises if outside match range with []" do
      "foo" =~ /foo/
      expect_raises(IndexError, "Invalid capture group index: 1") { $~[1] }
    end

    it "raises if special variable accessed on invalid capture group" do
      "spice" =~ /spice(s)?/
      expect_raises(IndexError, "Capture group 1 was not matched") { $1 }
      expect_raises(IndexError, "Invalid capture group index: 3") { $3 }
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

    it "can use negative index" do
      "foo" =~ /(b)?(f)(oo)/
      $~[-1]?.should eq("oo")
      $~[-2]?.should eq("f")
      $~[-3]?.should be_nil
      $~[-4]?.should eq("foo")
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

  describe "#captures" do
    it "gets an array of unnamed captures" do
      "Crystal".match(/(Cr)y/).not_nil!.captures.should eq(["Cr"])
      "Crystal".match(/(Cr)(?<name1>y)(st)(?<name2>al)/).not_nil!.captures.should eq(["Cr", "st"])
    end

    it "gets an array of unnamed captures with optional" do
      "Crystal".match(/(Cr)(s)?/).not_nil!.captures.should eq(["Cr", nil])
      "Crystal".match(/(Cr)(?<name1>s)?(tal)?/).not_nil!.captures.should eq(["Cr", nil])
    end
  end

  describe "#named_captures" do
    it "gets a hash of named captures" do
      "Crystal".match(/(?<name1>Cr)y/).not_nil!.named_captures.should eq({"name1" => "Cr"})
      "Crystal".match(/(Cr)(?<name1>y)(st)(?<name2>al)/).not_nil!.named_captures.should eq({"name1" => "y", "name2" => "al"})
    end

    it "gets a hash of named captures with optional" do
      "Crystal".match(/(?<name1>Cr)(?<name2>s)?/).not_nil!.named_captures.should eq({"name1" => "Cr", "name2" => nil})
      "Crystal".match(/(Cr)(?<name1>s)?(t)?(?<name2>al)?/).not_nil!.named_captures.should eq({"name1" => nil, "name2" => nil})
    end
  end

  describe "#to_a" do
    it "converts into an array" do
      "Crystal".match(/(?<name1>Cr)(y)/).not_nil!.to_a.should eq(["Cry", "Cr", "y"])
      "Crystal".match(/(Cr)(?<name1>y)(st)(?<name2>al)/).not_nil!.to_a.should eq(["Crystal", "Cr", "y", "st", "al"])
    end

    it "converts into an array having nil" do
      "Crystal".match(/(?<name1>Cr)(s)?/).not_nil!.to_a.should eq(["Cr", "Cr", nil])
      "Crystal".match(/(Cr)(?<name1>s)?(yst)?(?<name2>al)?/).not_nil!.to_a.should eq(["Crystal", "Cr", nil, "yst", "al"])
    end
  end

  describe "#to_h" do
    it "converts into a hash" do
      "Crystal".match(/(?<name1>Cr)(y)/).not_nil!.to_h.should eq({
              0 => "Cry",
        "name1" => "Cr",
              2 => "y",
      })
      "Crystal".match(/(Cr)(?<name1>y)(st)(?<name2>al)/).not_nil!.to_h.should eq({
              0 => "Crystal",
              1 => "Cr",
        "name1" => "y",
              3 => "st",
        "name2" => "al",
      })
    end

    it "converts into a hash having nil" do
      "Crystal".match(/(?<name1>Cr)(s)?/).not_nil!.to_h.should eq({
              0 => "Cr",
        "name1" => "Cr",
              2 => nil,
      })
      "Crystal".match(/(Cr)(?<name1>s)?(yst)?(?<name2>al)?/).not_nil!.to_h.should eq({
              0 => "Crystal",
              1 => "Cr",
        "name1" => nil,
              3 => "yst",
        "name2" => "al",
      })
    end
  end

  it "can check equality" do
    re = /((?<hello>he)llo)/
    m1 = re.match("hello")
    m2 = re.match("hello")
    m1.should be_truthy
    m2.should be_truthy
    m1.should eq(m2)
  end
end
