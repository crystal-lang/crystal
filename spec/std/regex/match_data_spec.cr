require "spec"

private def matchdata(re, string)
  re.match(string).should_not be_nil
end

describe "Regex::MatchData" do
  it "#regex" do
    regex = /foo/
    matchdata(regex, "foo").regex.should be(regex)
  end

  it "#string" do
    string = "foo"
    matchdata(/foo/, string).string.should be(string)
  end

  it "#inspect" do
    matchdata(/f(o)(x)/, "the fox").inspect.should eq(%(Regex::MatchData("fox" 1:"o" 2:"x")))
    matchdata(/f(o)(x)?/, "the fort").inspect.should eq(%(Regex::MatchData("fo" 1:"o" 2:nil)))
    matchdata(/fox/, "the fox").inspect.should eq(%(Regex::MatchData("fox")))
  end

  it "#to_s" do
    matchdata(/f(o)(x)/, "the fox").to_s.should eq(%(Regex::MatchData("fox" 1:"o" 2:"x")))
    matchdata(/f(?<lettero>o)(?<letterx>x)/, "the fox").to_s.should eq(%(Regex::MatchData("fox" lettero:"o" letterx:"x")))
    matchdata(/fox/, "the fox").to_s.should eq(%(Regex::MatchData("fox")))
  end

  it "#pretty_print" do
    matchdata(/f(o)(x)?/, "the fo").pretty_inspect.should eq(%(Regex::MatchData("fo" 1:"o" 2:nil)))

    expected = <<-REGEX
      Regex::MatchData("foooo"
       first:"f"
       second:"oooo"
       third:"ooo"
       fourth:"oo"
       fifth:"o")
      REGEX

    matchdata(/(?<first>f)(?<second>o(?<third>o(?<fourth>o(?<fifth>o))))/, "fooooo").pretty_inspect.should eq(expected)
  end

  it "#size" do
    matchdata(/[p-s]/, "Crystal").size.should eq(1)
    matchdata(/r(ys)/, "Crystal").size.should eq(2)
    matchdata(/r(ys)(?<ok>ta)/, "Crystal").size.should eq(3)
  end

  describe "#[]" do
    it "captures empty group" do
      md = matchdata(/(?<g1>z?)foo/, "foo")
      md[1].should eq("")
      md["g1"].should eq("")
    end

    it "capture named group" do
      md = matchdata(/f(?<g1>o+)(?<g2>bar?)/, "fooba")
      md["g1"].should eq("oo")
      md["g2"].should eq("ba")
    end

    it "captures duplicated named group" do
      re = /(?:(?<g1>foo)|(?<g1>bar))*/

      matchdata(re, "foo")["g1"].should eq("foo")
      matchdata(re, "bar")["g1"].should eq("bar")
      matchdata(re, "foobar")["g1"].should eq("bar")
      matchdata(re, "barfoo")["g1"].should eq("foo")
    end

    it "can use negative index" do
      md = matchdata(/(f)(oo)/, "foo")
      md[-1].should eq("oo")
      md[-2].should eq("f")
      md[-3].should eq("foo")
      expect_raises(IndexError, "Invalid capture group index: -4") { md[-4] }
    end

    it "raises exception when named group doesn't exist" do
      md = matchdata(/foo/, "foo")
      expect_raises(KeyError, "Capture group 'group' does not exist") { md["group"] }
    end

    it "raises exception on optional empty group" do
      md = matchdata(/(?<g1>z)?foo/, "foo")
      expect_raises(IndexError, "Capture group 1 was not matched") { md[1] }
      expect_raises(KeyError, "Capture group 'g1' was not matched") { md["g1"] }
    end

    it "raises if outside match range with []" do
      md = matchdata(/foo/, "foo")
      expect_raises(IndexError, "Invalid capture group index: 1") { md[1] }
    end

    it "raises if special variable accessed on invalid capture group" do
      md = matchdata(/spice(s)?/, "spice")
      expect_raises(IndexError, "Capture group 1 was not matched") { md[1] }
      expect_raises(IndexError, "Invalid capture group index: 3") { md[3] }
    end

    it "can use range" do
      md = matchdata(/(a)(b)/, "ab")
      md[1..2].should eq(["a", "b"])
      md[1..].should eq(["a", "b"])
      md[..].should eq(["ab", "a", "b"])
      expect_raises(IndexError) { md[4..] }
    end

    it "can use start and count" do
      md = matchdata(/(a)(b)/, "ab")
      md[1, 2].should eq(["a", "b"])
      expect_raises(IndexError) { md[4, 1] }
    end
  end

  describe "#[]?" do
    it "capture empty group" do
      md = matchdata(/(?<g1>z?)foo/, "foo")
      md[1]?.should eq("")
      md["g1"]?.should eq("")
    end

    it "capture optional empty group" do
      md = matchdata(/(?<g1>z)?foo/, "foo")
      md[1]?.should be_nil
      md["g1"]?.should be_nil
    end

    it "capture named group" do
      md = matchdata(/f(?<g1>o+)(?<g2>bar?)/, "fooba")
      md["g1"]?.should eq("oo")
      md["g2"]?.should eq("ba")
    end

    it "captures duplicated named group" do
      re = /(?:(?<g1>foo)|(?<g1>bar))*/

      md = matchdata(re, "foo")
      md["g1"]?.should eq("foo")

      md = matchdata(re, "bar")
      md["g1"]?.should eq("bar")

      md = matchdata(re, "foobar")
      md["g1"]?.should eq("bar")

      md = matchdata(re, "barfoo")
      md["g1"]?.should eq("foo")
    end

    it "can use negative index" do
      md = matchdata(/(b)?(f)(oo)/, "foo")
      md[-1]?.should eq("oo")
      md[-2]?.should eq("f")
      md[-3]?.should be_nil
      md[-4]?.should eq("foo")
    end

    it "returns nil exception when named group doesn't exist" do
      md = matchdata(/foo/, "foo")
      md["group"]?.should be_nil
    end

    it "returns nil if outside match range with []" do
      md = matchdata(/foo/, "foo")
      md[1]?.should be_nil
    end

    it "can use range" do
      md = matchdata(/(a)(b)/, "ab")
      md[1..2]?.should eq(["a", "b"])
      md[1..]?.should eq(["a", "b"])
      md[..]?.should eq(["ab", "a", "b"])
      md[4..]?.should be_nil
    end

    it "can use start and count" do
      md = matchdata(/(a)(b)/, "ab")
      md[1, 2]?.should eq(["a", "b"])
      md[4, 1]?.should be_nil
    end
  end

  describe "#post_match" do
    it "returns an empty string when there's nothing after" do
      matchdata(/ystal/, "Crystal").post_match.should eq ""
    end

    it "returns the part of the string after the match" do
      matchdata(/yst/, "Crystal").post_match.should eq "al"
    end

    it "works with unicode" do
      matchdata(/本/, "há日本語").post_match.should eq "語"
    end
  end

  describe "#pre_match" do
    it "returns an empty string when there's nothing before" do
      matchdata(/Cryst/, "Crystal").pre_match.should eq ""
    end

    it "returns the part of the string before the match" do
      matchdata(/yst/, "Crystal").pre_match.should eq "Cr"
    end

    it "works with unicode" do
      matchdata(/本/, "há日本語").pre_match.should eq "há日"
    end
  end

  describe "#captures" do
    it "gets an array of unnamed captures" do
      matchdata(/(Cr)y/, "Crystal").captures.should eq(["Cr"])
      matchdata(/(Cr)(?<name1>y)(st)(?<name2>al)/, "Crystal").captures.should eq(["Cr", "st"])
    end

    it "gets an array of unnamed captures with optional" do
      matchdata(/(Cr)(s)?/, "Crystal").captures.should eq(["Cr", nil])
      matchdata(/(Cr)(?<name1>s)?(tal)?/, "Crystal").captures.should eq(["Cr", nil])
    end
  end

  describe "#named_captures" do
    it "gets a hash of named captures" do
      matchdata(/(?<name1>Cr)y/, "Crystal").named_captures.should eq({"name1" => "Cr"})
      matchdata(/(Cr)(?<name1>y)(st)(?<name2>al)/, "Crystal").named_captures.should eq({"name1" => "y", "name2" => "al"})
    end

    it "gets a hash of named captures with optional" do
      matchdata(/(?<name1>Cr)(?<name2>s)?/, "Crystal").named_captures.should eq({"name1" => "Cr", "name2" => nil})
      matchdata(/(Cr)(?<name1>s)?(t)?(?<name2>al)?/, "Crystal").named_captures.should eq({"name1" => nil, "name2" => nil})
    end

    it "gets a hash of named captures with duplicated name" do
      matchdata(/(?<name>Cr)y(?<name>s)/, "Crystal").named_captures.should eq({"name" => "s"})
    end
  end

  describe "#to_a" do
    it "converts into an array" do
      matchdata(/(?<name1>Cr)(y)/, "Crystal").to_a.should eq(["Cry", "Cr", "y"])
      matchdata(/(Cr)(?<name1>y)(st)(?<name2>al)/, "Crystal").to_a.should eq(["Crystal", "Cr", "y", "st", "al"])
    end

    it "converts into an array having nil" do
      matchdata(/(?<name1>Cr)(s)?/, "Crystal").to_a.should eq(["Cr", "Cr", nil])
      matchdata(/(Cr)(?<name1>s)?(yst)?(?<name2>al)?/, "Crystal").to_a.should eq(["Crystal", "Cr", nil, "yst", "al"])
    end
  end

  describe "#to_h" do
    it "converts into a hash" do
      matchdata(/(?<name1>Cr)(y)/, "Crystal").to_h.should eq({
              0 => "Cry",
        "name1" => "Cr",
              2 => "y",
      })
      matchdata(/(Cr)(?<name1>y)(st)(?<name2>al)/, "Crystal").to_h.should eq({
              0 => "Crystal",
              1 => "Cr",
        "name1" => "y",
              3 => "st",
        "name2" => "al",
      })
    end

    it "converts into a hash having nil" do
      matchdata(/(?<name1>Cr)(s)?/, "Crystal").to_h.should eq({
              0 => "Cr",
        "name1" => "Cr",
              2 => nil,
      })
      matchdata(/(Cr)(?<name1>s)?(yst)?(?<name2>al)?/, "Crystal").to_h.should eq({
              0 => "Crystal",
              1 => "Cr",
        "name1" => nil,
              3 => "yst",
        "name2" => "al",
      })
    end

    it "converts into a hash with duplicated names" do
      matchdata(/(Cr)(?<name>s)?(yst)?(?<name>al)?/, "Crystal").to_h.should eq({
             0 => "Crystal",
             1 => "Cr",
        "name" => "al",
             3 => "yst",
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

  it "hashes" do
    re = /(a|b)/
    hash = re.match("a").hash
    hash.should eq(re.match("a").hash)
    hash.should_not eq(re.match("b").hash)
  end
end
