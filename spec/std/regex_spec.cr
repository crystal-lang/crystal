require "./spec_helper"

describe "Regex" do
  describe ".new" do
    it "doesn't crash when PCRE tries to free some memory (#771)" do
      expect_raises(ArgumentError) { Regex.new("foo)") }
    end

    it "raises exception with invalid regex" do
      expect_raises(ArgumentError) { Regex.new("+") }
    end

    describe "options" do
      it "regular" do
        Regex.new("", Regex::CompileOptions::ANCHORED).options.anchored?.should be_true
      end

      it "unnamed option" do
        {% if Regex::Engine.resolve.name == "Regex::PCRE" %}
          Regex.new("^/foo$", Regex::CompileOptions.new(0x00000020)).matches?("/foo\n").should be_false
        {% else %}
          expect_raises ArgumentError, "Unknown Regex::Option value: 64" do
            Regex.new("", Regex::CompileOptions.new(0x00000040))
          end
        {% end %}
      end
    end

    it "raises on invalid UTF-8" do
      expect_raises(ArgumentError, /invalid UTF-8 string|UTF-8 error/) do
        Regex.new("\x96")
      end
      Regex.new("\x96", :NO_UTF_CHECK).should be_a(Regex)
    end
  end

  it ".literal" do
    Regex.literal("foo").should eq /foo/
    Regex.literal("foo", i: true).should eq /foo/i
    Regex.literal("foo", i: true, m: true).should eq /foo/im
    Regex.literal("foo", i: true, m: true, x: true).should eq /foo/imx
    Regex.literal("foo", x: true).should eq /foo/x
  end

  it "#options" do
    /cat/.options.ignore_case?.should be_false
    /cat/i.options.ignore_case?.should be_true
    /cat/.options.multiline?.should be_false
    /cat/m.options.multiline?.should be_true
    /cat/.options.extended?.should be_false
    /cat/x.options.extended?.should be_true
    /cat/mx.options.multiline?.should be_true
    /cat/mx.options.extended?.should be_true
    /cat/mx.options.ignore_case?.should be_false
    /cat/xi.options.ignore_case?.should be_true
    /cat/xi.options.extended?.should be_true
    /cat/xi.options.multiline?.should be_false
  end

  it "#source" do
    /foo/.source.should eq "foo"
    /(foo|bar)*/.source.should eq "(foo|bar)*"
    /foo\x96/.source.should eq "foo\\x96"
    Regex.new("").source.should eq ""
  end

  describe "#match" do
    it "returns matchdata" do
      md = /(?<bar>.)(?<foo>.)/.match("Crystal").should_not be_nil
      md[0].should eq "Cr"
      md.captures.should eq [] of String
      md.named_captures.should eq({"bar" => "C", "foo" => "r"})
    end

    it "assigns captures" do
      matchdata = /foo/.match("foo")
      $~.should eq(matchdata)

      /foo/.match("bar")
      expect_raises(NilAssertionError) { $~ }
    end

    it "returns nil on non-match" do
      /Crystal/.match("foo").should be_nil
    end

    describe "with pos" do
      it "positive" do
        /foo/.match("foo", 0).should_not be_nil
        /foo/.match("foo", 1).should be_nil
        /foo/.match(".foo", 1).should_not be_nil
        /foo/.match("..foo", 1).should_not be_nil

        /foo/.match("bar", 0).should be_nil
        /foo/.match("bar", 1).should be_nil
      end

      it "char index" do
        /foo/.match("öfoo", 1).should_not be_nil
      end

      pending "negative" do
        /foo/.match("..foo", -3).should_not be_nil
        /foo/.match("..foo", -2).should be_nil
      end
    end

    context "with options" do
      it "deprecated Regex::Options" do
        /foo/.match(".foo", options: Regex::Options::ANCHORED).should be_nil
        /foo/.match("foo", options: Regex::Options::ANCHORED).should_not be_nil
      end

      it "Regex::Match options" do
        /foo/.match(".foo", options: Regex::MatchOptions::ANCHORED).should be_nil
        /foo/.match("foo", options: Regex::MatchOptions::ANCHORED).should_not be_nil
      end
    end

    it "with invalid UTF-8" do
      expect_raises(ArgumentError, "UTF-8 error") do
        /([\w_\.@#\/\*])+/.match("\xFF\xFE")
      end

      if Regex::Engine.version_number >= {10, 36}
        Regex.new("([\\w_\\.@#\\/\\*])+", options: Regex::Options::MATCH_INVALID_UTF).match("\xFF\xFE").should be_nil
      end
    end

    it "skip invalid UTF check" do
      # no exception raised
      /f.o/.matches?("f\xFFo", options: Regex::MatchOptions::NO_UTF_CHECK)
    end
  end

  describe "#match!" do
    it "returns match data" do
      md = /(?<bar>.)(?<foo>.)/.match!("Crystal")
      md[0].should eq "Cr"
      md.captures.should eq [] of String
      md.named_captures.should eq({"bar" => "C", "foo" => "r"})
    end

    it "assigns captures" do
      md = /foo/.match!("foo")
      $~.should eq md
    end

    it "raises on non-match" do
      expect_raises(Regex::Error, "Match not found") { /Crystal/.match!("foo") }
      expect_raises(NilAssertionError) { $~ }
    end

    context "with options" do
      it "Regex::Match options" do
        expect_raises(Regex::Error, "Match not found") do
          /foo/.match!(".foo", options: Regex::MatchOptions::ANCHORED)
        end
      end
    end
  end

  describe "#match_at_byte_index" do
    it "assigns captures" do
      matchdata = /foo/.match_at_byte_index("..foo", 1)
      $~.should eq(matchdata)

      /foo/.match_at_byte_index("foo", 1)
      expect_raises(NilAssertionError) { $~ }

      /foo/.match("foo") # make sure $~ is assigned
      $~.should_not be_nil

      /foo/.match_at_byte_index("foo", 5)
      expect_raises(NilAssertionError) { $~ }
    end

    it "positive index" do
      md = /foo/.match_at_byte_index("foo", 0).should_not be_nil
      md.begin.should eq 0
      /foo/.match_at_byte_index("foo", 1).should be_nil
      md = /foo/.match_at_byte_index(".foo", 1).should_not be_nil
      md.begin.should eq 1
      md = /foo/.match_at_byte_index("..foo", 1).should_not be_nil
      md.begin.should eq 2
      /foo/.match_at_byte_index("foo", 5).should be_nil

      /foo/.match_at_byte_index("bar", 0).should be_nil
      /foo/.match_at_byte_index("bar", 1).should be_nil
    end

    it "multibyte index" do
      expect_raises(ArgumentError, "bad offset into UTF string") do
        /foo/.match_at_byte_index("öfoo", 1)
      end

      if Regex::Engine.version_number >= {10, 36}
        md = Regex.new("foo", options: Regex::CompileOptions::MATCH_INVALID_UTF).match_at_byte_index("öfoo", 1).should_not be_nil
        md.begin.should eq 1
        md.byte_begin.should eq 2
      end

      md = /foo/.match_at_byte_index("öfoo", 2).should_not be_nil
      md.begin.should eq 1
      md.byte_begin.should eq 2
    end

    pending "negative" do
      md = /foo/.match_at_byte_index("..foo", -3).should_not be_nil
      md.begin.should eq 0
      /foo/.match_at_byte_index("..foo", -2).should be_nil
    end

    context "with options" do
      it "deprecated Regex::Options" do
        /foo/.match_at_byte_index("..foo", 1, options: Regex::Options::ANCHORED).should be_nil
        /foo/.match_at_byte_index(".foo", 1, options: Regex::Options::ANCHORED).should_not be_nil
      end

      it "Regex::MatchOptions" do
        /foo/.match_at_byte_index("..foo", 1, options: Regex::MatchOptions::ANCHORED).should be_nil
        /foo/.match_at_byte_index(".foo", 1, options: Regex::MatchOptions::ANCHORED).should_not be_nil
      end
    end
  end

  describe "#matches?" do
    it "basic" do
      /foo/.matches?("foo").should be_true
      expect_raises(NilAssertionError) { $~ }
      /foo/.matches?("bar").should be_false
      expect_raises(NilAssertionError) { $~ }
    end

    describe "options" do
      it "ignore case" do
        /hello/.matches?("HeLlO").should be_false
        /hello/i.matches?("HeLlO").should be_true
      end

      describe "multiline" do
        it "anchor" do
          /^bar/.matches?("foo\nbar").should be_false
          /^bar/m.matches?("foo\nbar").should be_true
        end

        it "span" do
          /<bar.*?>/.matches?("foo\n<bar\n>baz").should be_false
          /<bar.*?>/m.matches?("foo\n<bar\n>baz").should be_true
        end
      end

      describe "extended" do
        it "ignores white space" do
          /foo   bar/.matches?("foobar").should be_false
          /foo   bar/x.matches?("foobar").should be_true
        end

        it "ignores comments" do
          /foo#comment\nbar/.matches?("foobar").should be_false
          /foo#comment\nbar/x.matches?("foobar").should be_true
        end
      end

      it "anchored" do
        Regex.new("foo", Regex::CompileOptions::ANCHORED).matches?("foo").should be_true
        Regex.new("foo", Regex::CompileOptions::ANCHORED).matches?(".foo").should be_false
      end
    end

    describe "unicode" do
      it "unicode support" do
        /ん/.matches?("こんに").should be_true
      end

      it "matches unicode char against [[:alnum:]] (#4704)" do
        /[[:alnum:]]/.matches?("à").should be_true
      end

      it "matches unicode char against [[:print:]] (#11262)" do
        /[[:print:]]/.matches?("\n☃").should be_true
      end

      it "invalid codepoint" do
        expect_raises(ArgumentError, "UTF-8 error") do
          /foo/.matches?("f\x96o")
        end

        if Regex::Engine.version_number >= {10, 36}
          Regex.new("foo", options: Regex::CompileOptions::MATCH_INVALID_UTF).matches?("f\x96o").should be_false
          Regex.new("f\x96o", options: Regex::CompileOptions::MATCH_INVALID_UTF | Regex::CompileOptions::NO_UTF_CHECK).matches?("f\x96o").should be_false
          Regex.new("f.o", options: Regex::CompileOptions::MATCH_INVALID_UTF).matches?("f\x96o").should be_false
          Regex.new("\\bf\\b", options: Regex::CompileOptions::MATCH_INVALID_UTF).matches?("f\x96o").should be_true
          Regex.new("\\bo\\b", options: Regex::CompileOptions::MATCH_INVALID_UTF).matches?("f\x96o").should be_true
        end
      end
    end

    context "with options" do
      it "deprecated Regex::Options" do
        /foo/.matches?(".foo", options: Regex::Options::ANCHORED).should be_false
        /foo/.matches?("foo", options: Regex::Options::ANCHORED).should be_true
      end

      it "Regex::MatchOptions" do
        /foo/.matches?(".foo", options: Regex::MatchOptions::ANCHORED).should be_false
        /foo/.matches?("foo", options: Regex::MatchOptions::ANCHORED).should be_true
      end
    end

    it "doesn't crash with a large single line string" do
      str = File.read(datapath("large_single_line_string.txt"))

      {% if Regex::Engine.resolve.name == "Regex::PCRE" %}
        jit_enabled = uninitialized LibC::Int
        LibPCRE.config LibPCRE::CONFIG_JIT, pointerof(jit_enabled)
        pending! "PCRE JIT mode not available." unless 1 == jit_enabled

        # This match may raise on JIT stack limit or not. If it raises, the error message should be the expected one.
        begin
          str.matches?(/^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/)
        rescue exc : Exception
          exc.to_s.should eq("Regex match error: JIT_STACKLIMIT")
        end
      {% else %}
        # Can't use regex literal because the *LIMIT_DEPTH verb is not supported in libpcre (only libpcre2)
        # and thus the compiler doesn't recognize it.
        regex = Regex.new("(*LIMIT_DEPTH=8192)^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
        pending! "PCRE2 JIT mode not available." unless regex.@jit
        str.matches?(regex)
      {% end %}
      # We don't care whether this actually matches or not, it's just to make
      # sure the engine does not stack overflow with a large string.
    end
  end

  describe "#matches_at_byte_index?" do
    it "positive index" do
      /foo/.matches_at_byte_index?("foo", 0).should be_true
      /foo/.matches_at_byte_index?("foo", 1).should be_false
      /foo/.matches_at_byte_index?(".foo", 1).should be_true
      /foo/.matches_at_byte_index?("..foo", 1).should be_true
      /foo/.matches_at_byte_index?("foo", 5).should be_false

      /foo/.matches_at_byte_index?("bar", 0).should be_false
      /foo/.matches_at_byte_index?("bar", 1).should be_false
    end

    it "multibyte index" do
      expect_raises(ArgumentError, "bad offset into UTF string") do
        /foo/.matches_at_byte_index?("öfoo", 1)
      end

      if Regex::Engine.version_number >= {10, 36}
        Regex.new("foo", options: Regex::CompileOptions::MATCH_INVALID_UTF).matches_at_byte_index?("öfoo", 1).should be_true
      end
      /foo/.matches_at_byte_index?("öfoo", 2).should be_true
    end

    pending "negative" do
      /foo/.matches_at_byte_index?("..foo", -3).should be_true
      /foo/.matches_at_byte_index?("..foo", -2).should be_false
    end

    context "with options" do
      it "deprecated Regex::Options" do
        /foo/.matches_at_byte_index?("..foo", 1, options: Regex::Options::ANCHORED).should be_false
        /foo/.matches_at_byte_index?(".foo", 1, options: Regex::Options::ANCHORED).should be_true
      end

      it "Regex::MatchOptions" do
        /foo/.matches_at_byte_index?("..foo", 1, options: Regex::MatchOptions::ANCHORED).should be_false
        /foo/.matches_at_byte_index?(".foo", 1, options: Regex::MatchOptions::ANCHORED).should be_true
      end
    end
  end

  describe "#===" do
    it "basic" do
      (/f(o+)(bar?)/ === "fooba").should be_true
      (/f(o+)(bar?)/ === "pooba").should be_false
    end

    it "assigns captures" do
      /f(o+)(bar?)/ === "fooba"
      $~.group_size.should eq(2)
      $1.should eq("oo")
      $2.should eq("ba")

      /f(o+)(bar?)/ === "pooba"
      expect_raises(NilAssertionError) { $~ }
    end
  end

  describe "#=~" do
    it "returns match index or nil" do
      (/foo/ =~ "bar foo baz").should eq(4)
      (/foo/ =~ "bar boo baz").should be_nil
    end

    it "assigns captures" do
      "fooba" =~ /f(o+)(bar?)/
      $~.group_size.should eq(2)
      $1.should eq("oo")
      $2.should eq("ba")

      /foo/ =~ "bar boo baz"
      expect_raises(NilAssertionError) { $~ }
    end

    it "accepts any type" do
      (/foo/ =~ nil).should be_nil
      (/foo/ =~ 1).should be_nil
      (/foo/ =~ [1, 2]).should be_nil
      (/foo/ =~ true).should be_nil
    end
  end

  describe "#name_table" do
    it "is a map of capture group number to name" do
      (/(?<date> (?<year>(\d\d)?\d\d) - (?<month>\d\d) - (?<day>\d\d) )/x).name_table.should eq({
        1 => "date",
        2 => "year",
        4 => "month",
        5 => "day",
      })
    end

    it "alpanumeric" do
      /(?<f1>)/.name_table.should eq({1 => "f1"})
    end

    it "duplicate name" do
      /(?<foo>)(?<foo>)/.name_table.should eq({1 => "foo", 2 => "foo"})
    end

    it "more than 255 groups" do
      regex = Regex.new(Array.new(1000) { |i| "(?<c#{i}>.)" }.join)
      name_table = Array.new(1000) { |i| {i + 1, "c#{i}"} }.to_h
      regex.name_table.should eq(name_table)
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
      /foo/im.inspect.should eq("/foo/im")
      /foo/imx.inspect.should eq("/foo/imx")
    end

    it "escapes" do
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

    it "with slash" do
      %r(/).to_s.should eq("(?-imsx:\\/)")
      %r(\/).to_s.should eq("(?-imsx:\\/)")
    end

    it "interpolation" do
      regex = /(?<foo>R)/i
      /(?<bar>C)#{regex}/.should eq /(?<bar>C)(?i-msx:(?<foo>R))/
      /(?<bar>C)#{regex}/i.should eq /(?<bar>C)(?i-msx:(?<foo>R))/i
    end
  end

  it "#==" do
    regex = Regex.new("foo", Regex::CompileOptions::IGNORE_CASE)
    (regex == Regex.new("foo", Regex::CompileOptions::IGNORE_CASE)).should be_true
    (regex == Regex.new("foo")).should be_false
    (regex == Regex.new("bar", Regex::CompileOptions::IGNORE_CASE)).should be_false
    (regex == Regex.new("bar")).should be_false
  end

  it "#hash" do
    hash = Regex.new("foo", Regex::CompileOptions::IGNORE_CASE).hash
    hash.should eq(Regex.new("foo", Regex::CompileOptions::IGNORE_CASE).hash)
    hash.should_not eq(Regex.new("foo").hash)
    hash.should_not eq(Regex.new("bar", Regex::CompileOptions::IGNORE_CASE).hash)
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
    Regex.error?("(foo|bar").should eq(
      if Regex::Engine.to_s == "Regex::PCRE2"
        "missing closing parenthesis at 8"
      else
        "missing ) at 8"
      end
    )
  end

  it ".supports_compile_options?" do
    Regex.supports_compile_options?(:anchored).should be_true
    Regex.supports_compile_options?(:endanchored).should eq Regex::Engine.version_number >= {10, 0}
  end

  it ".supports_match_options?" do
    Regex.supports_match_options?(:anchored).should be_true
    Regex.supports_match_options?(:endanchored).should eq Regex::Engine.version_number >= {10, 0}
  end
end
