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
    matchdata(/foo(bar)?/, "foo").size.should eq(2)
    matchdata(/foo(bar)?/, "foobar").size.should eq(2)
  end

  describe "#begin" do
    it "no captures" do
      matchdata(/foo/, "foo").begin.should eq 0
      matchdata(/foo/, "foo").begin(-1).should eq 0
      matchdata(/foo/, ".foo.").begin.should eq 1
      matchdata(/foo/, ".foo.").begin(-1).should eq 1
    end

    it "out of range" do
      expect_raises(IndexError) do
        matchdata(/foo/, "foo").begin(1)
      end
    end

    it "with capture" do
      md = matchdata(/f(o)o/, "foo")
      md.begin.should eq 0
      md.begin(1).should eq 1
      md.begin(-1).should eq 1

      md = matchdata(/f(o)o/, ".foo.")
      md.begin.should eq 1
      md.begin(1).should eq 2
      md.begin(-1).should eq 2
    end

    it "with unmatched capture" do
      md = matchdata(/f(x)?o/, "foo")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.begin(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.begin(-1)
      end

      md = matchdata(/f(x)?o/, ".foo.")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.begin(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.begin(-1)
      end
    end

    it "char index" do
      matchdata(/foo/, "öfoo").begin.should eq 1
    end
  end

  describe "#byte_begin" do
    it "char index" do
      matchdata(/foo/, "öfoo").byte_begin.should eq 2
    end

    it "with unmatched capture" do
      md = matchdata(/f(x)?o/, "foo")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_begin(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_begin(-1)
      end

      md = matchdata(/f(x)?o/, ".foo.")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_begin(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_begin(-1)
      end
    end
  end

  describe "#end" do
    it "no captures" do
      matchdata(/foo/, "foo").end.should eq 3
      matchdata(/foo/, "foo").end(-1).should eq 3
      matchdata(/foo/, ".foo.").end.should eq 4
      matchdata(/foo/, ".foo.").end(-1).should eq 4
    end

    it "out of range" do
      expect_raises(IndexError) do
        matchdata(/foo/, "foo").end(1)
      end
    end

    it "with capture" do
      md = matchdata(/f(o)o/, "foo")
      md.end.should eq 3
      md.end(1).should eq 2
      md.end(-1).should eq 2

      md = matchdata(/f(o)o/, ".foo.")
      md.end.should eq 4
      md.end(1).should eq 3
      md.end(-1).should eq 3
    end

    it "with unmatched capture" do
      md = matchdata(/f(x)?o/, "foo")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.end(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.end(-1)
      end

      md = matchdata(/f(x)?o/, ".foo.")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.end(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.end(-1)
      end
    end

    it "char index" do
      matchdata(/foo/, "öfoo").end.should eq 4
    end
  end

  describe "#byte_end" do
    it "char index" do
      matchdata(/foo/, "öfoo").byte_end.should eq 5
    end

    it "with unmatched capture" do
      md = matchdata(/f(x)?o/, "foo")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_end(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_end(-1)
      end

      md = matchdata(/f(x)?o/, ".foo.")
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_end(1)
      end
      expect_raises(IndexError, "Capture group 1 was not matched") do
        md.byte_end(-1)
      end
    end
  end

  describe "#[]" do
    describe "String" do
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

      it "named groups with same prefix" do
        md = matchdata(/KEY_(?<key>\w+)\s+(?<keycode>.*)/, "KEY_POWER 116")
        md["key"].should eq "POWER"
        md["keycode"].should eq "116"
      end

      it "raises exception when named group doesn't exist" do
        md = matchdata(/foo/, "foo")
        expect_raises(KeyError, "Capture group 'group' does not exist") { md["group"] }

        expect_raises(KeyError, "Capture group 'groupwithlongname' does not exist") { md["groupwithlongname"] }
      end

      it "captures empty group" do
        matchdata(/(?<g1>z?)foo/, "foo")["g1"].should eq("")
      end

      it "raises exception on optional empty group" do
        md = matchdata(/(?<g1>z)?foo/, "foo")
        expect_raises(KeyError, "Capture group 'g1' was not matched") { md["g1"] }
      end
    end

    describe "Int" do
      it "can use negative index" do
        md = matchdata(/(f)(oo)/, "foo")
        md[-1].should eq("oo")
        md[-2].should eq("f")
        md[-3].should eq("foo")
        expect_raises(IndexError, "Invalid capture group index: -4") { md[-4] }
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

      it "captures empty group" do
        matchdata(/(?<g1>z?)foo/, "foo")[1].should eq("")
      end

      it "raises exception on optional empty group" do
        md = matchdata(/(?<g1>z)?foo/, "foo")
        expect_raises(IndexError, "Capture group 1 was not matched") { md[1] }
      end
    end

    describe "Range" do
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
  end

  describe "#[]?" do
    describe "String" do
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

      it "returns nil exception when named group doesn't exist" do
        md = matchdata(/foo/, "foo")
        md["group"]?.should be_nil
        md["groupwithlongname"]?.should be_nil
      end

      it "capture empty group" do
        matchdata(/(?<g1>z?)foo/, "foo")["g1"]?.should eq("")
      end

      it "capture optional empty group" do
        matchdata(/(?<g1>z)?foo/, "foo")["g1"]?.should be_nil
      end
    end

    describe "Int" do
      it "can use negative index" do
        md = matchdata(/(b)?(f)(oo)/, "foo")
        md[-1]?.should eq("oo")
        md[-2]?.should eq("f")
        md[-3]?.should be_nil
        md[-4]?.should eq("foo")
      end

      it "returns nil if outside match range with []" do
        md = matchdata(/foo/, "foo")
        md[1]?.should be_nil
      end

      it "capture empty group" do
        matchdata(/(?<g1>z?)foo/, "foo")[1]?.should eq("")
      end

      it "capture optional empty group" do
        matchdata(/(?<g1>z)?foo/, "foo")[1]?.should be_nil
      end
    end

    describe "Range" do
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

    it "doesn't get named captures when there are more than 255" do
      regex = Regex.new(Array.new(256) { |i| "(?<c#{i}>.)" }.join)
      matchdata(regex, "x" * 256).captures.should eq([] of String)
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

    it "gets more than 127 named captures" do
      regex = Regex.new(Array.new(128) { |i| "(?<c#{i}>.)" }.join)
      captures = matchdata(regex, "x" * 128).named_captures
      captures.size.should eq(128)
      128.times { |i| captures["c#{i}"].should eq("x") }
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

  it "#==" do
    re = /((?<hello>he)llo)/
    m1 = re.match("hello")
    m2 = re.match("hello")
    m1.should be_truthy
    m2.should be_truthy
    m1.should eq(m2)
  end

  it "#hash" do
    re = /(a|b)/
    hash = re.match("a").hash
    hash.should eq(re.match("a").hash)
    hash.should_not eq(re.match("b").hash)
  end
end
