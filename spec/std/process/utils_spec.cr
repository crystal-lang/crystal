require "spec"

describe Process do
  describe ".executable_path" do
    it "searches executable" do
      Process.executable_path.should be_a(String | Nil)
    end
  end

  describe ".quote_posix" do
    it { Process.quote_posix("").should eq "''" }
    it { Process.quote_posix(" ").should eq "' '" }
    it { Process.quote_posix("$hi").should eq "'$hi'" }
    it { Process.quote_posix(orig = "aZ5+,-./:=@_").should eq orig }
    it { Process.quote_posix(orig = "cafe").should eq orig }
    it { Process.quote_posix("café").should eq "'café'" }
    it { Process.quote_posix("I'll").should eq %('I'"'"'ll') }
    it { Process.quote_posix("'").should eq %(''"'"'') }
    it { Process.quote_posix("\\").should eq "'\\'" }

    context "join" do
      it { Process.quote_posix([] of String).should eq "" }
      it { Process.quote_posix(["my file.txt", "another.txt"]).should eq "'my file.txt' another.txt" }
      it { Process.quote_posix(["foo ", "", " ", " bar"]).should eq "'foo ' '' ' ' ' bar'" }
      it { Process.quote_posix(["foo'", "\"bar"]).should eq %('foo'"'"'' '"bar') }
    end
  end

  describe ".quote_windows" do
    it { Process.quote_windows("").should eq %("") }
    it { Process.quote_windows(" ").should eq %(" ") }
    it { Process.quote_windows(orig = "%hi%").should eq orig }
    it { Process.quote_windows(%q(C:\"foo" project.txt)).should eq %q("C:\\\"foo\" project.txt") }
    it { Process.quote_windows(%q(C:\"foo"_project.txt)).should eq %q(C:\\\"foo\"_project.txt) }
    it { Process.quote_windows(%q(C:\Program Files\Foo Bar\foobar.exe)).should eq %q("C:\Program Files\Foo Bar\foobar.exe") }
    it { Process.quote_windows(orig = "café").should eq orig }
    it { Process.quote_windows(%(")).should eq %q(\") }
    it { Process.quote_windows(%q(a\\b\ c\)).should eq %q("a\\b\ c\\") }
    it { Process.quote_windows(orig = %q(a\\b\c\)).should eq orig }

    context "join" do
      it { Process.quote_windows([] of String).should eq "" }
      it { Process.quote_windows(["my file.txt", "another.txt"]).should eq %("my file.txt" another.txt) }
      it { Process.quote_windows(["foo ", "", " ", " bar"]).should eq %("foo " "" " " " bar") }
    end
  end

  {% if flag?(:unix) %}
    describe ".parse_arguments" do
      it "uses the native platform rules" do
        Process.parse_arguments(%q[a\ b'c']).should eq [%q[a bc]]
      end
    end
  {% elsif flag?(:win32) %}
    describe ".parse_arguments" do
      it "uses the native platform rules" do
        Process.parse_arguments(%q[a\ b'c']).should eq [%q[a\], %q[b'c']]
      end
    end
  {% else %}
    pending ".parse_arguments"
  {% end %}

  describe ".parse_arguments_posix" do
    it { Process.parse_arguments_posix(%q[]).should eq([] of String) }
    it { Process.parse_arguments_posix(%q[ ]).should eq([] of String) }
    it { Process.parse_arguments_posix(%q[foo]).should eq [%q[foo]] }
    it { Process.parse_arguments_posix(%q[foo bar]).should eq [%q[foo], %q[bar]] }
    it { Process.parse_arguments_posix(%q["foo bar" 'foo bar' baz]).should eq [%q[foo bar], %q[foo bar], %q[baz]] }
    it { Process.parse_arguments_posix(%q["foo bar"'foo bar'baz]).should eq [%q[foo barfoo barbaz]] }
    it { Process.parse_arguments_posix(%q[foo\ bar]).should eq [%q[foo bar]] }
    it { Process.parse_arguments_posix(%q["foo\ bar"]).should eq [%q[foo\ bar]] }
    it { Process.parse_arguments_posix(%q['foo\ bar']).should eq [%q[foo\ bar]] }
    it { Process.parse_arguments_posix(%q[\]).should eq [%q[\]] }
    it { Process.parse_arguments_posix(%q["foo bar" '\hello/' Fizz\ Buzz]).should eq [%q[foo bar], %q[\hello/], %q[Fizz Buzz]] }
    it { Process.parse_arguments_posix(%q[foo"bar"baz]).should eq [%q[foobarbaz]] }
    it { Process.parse_arguments_posix(%q[foo'bar'baz]).should eq [%q[foobarbaz]] }
    it { Process.parse_arguments_posix(%q[this 'is a "'very wei"rd co"m"mand please" don't do t'h'a't p"leas"e]).should eq [%q[this], %q[is a "very], %q[weird command please], %q[dont do that], %q[please]] }

    it "raises an error when double quote is unclosed" do
      expect_raises ArgumentError, "Unmatched quote" do
        Process.parse_arguments_posix(%q["foo])
      end
    end

    it "raises an error if single quote is unclosed" do
      expect_raises ArgumentError, "Unmatched quote" do
        Process.parse_arguments_posix(%q['foo])
      end
    end
  end

  describe ".parse_arguments_windows" do
    it { Process.parse_arguments_windows(%q[]).should eq([] of String) }
    it { Process.parse_arguments_windows(%q[ ]).should eq([] of String) }
    it { Process.parse_arguments_windows(%q[foo]).should eq [%q[foo]] }
    it { Process.parse_arguments_windows(%q[foo bar]).should eq [%q[foo], %q[bar]] }
    it { Process.parse_arguments_windows(%q["foo bar" 'foo bar' baz]).should eq [%q[foo bar], %q['foo], %q[bar'], %q[baz]] }
    it { Process.parse_arguments_windows(%q["foo bar"baz]).should eq [%q[foo barbaz]] }
    it { Process.parse_arguments_windows(%q[foo"bar baz"]).should eq [%q[foobar baz]] }
    it { Process.parse_arguments_windows(%q[foo\bar]).should eq [%q[foo\bar]] }
    it { Process.parse_arguments_windows(%q[foo\ bar]).should eq [%q[foo\], %q[bar]] }
    it { Process.parse_arguments_windows(%q[foo\\bar]).should eq [%q[foo\\bar]] }
    it { Process.parse_arguments_windows(%q[foo\\\bar]).should eq [%q[foo\\\bar]] }
    it { Process.parse_arguments_windows(%q[ /LIBPATH:C:\crystal\lib ]).should eq [%q[/LIBPATH:C:\crystal\lib]] }
    it { Process.parse_arguments_windows(%q[a\\\b d"e f"g h]).should eq [%q[a\\\b], %q[de fg], %q[h]] }
    it { Process.parse_arguments_windows(%q[a\\\"b c d]).should eq [%q[a\"b], %q[c], %q[d]] }
    it { Process.parse_arguments_windows(%q[a\\\\"b c" d e]).should eq [%q[a\\b c], %q[d], %q[e]] }
    it { Process.parse_arguments_windows(%q["foo bar" '\hello/' Fizz\ Buzz]).should eq [%q[foo bar], %q['\hello/'], %q[Fizz\], %q[Buzz]] }
    it { Process.parse_arguments_windows(%q[this 'is a "'very wei"rd co"m"mand please" don't do t'h'a't p"leas"e"]).should eq [%q[this], %q['is], %q[a], %q['very weird], %q[command], %q[please don't do t'h'a't please]] }

    it "raises an error if double quote is unclosed" do
      expect_raises ArgumentError, "Unmatched quote" do
        Process.parse_arguments_windows(%q["foo])
        Process.parse_arguments_windows(%q[\"foo])
        Process.parse_arguments_windows(%q["f\"oo\\\"])
      end
    end
  end
end
