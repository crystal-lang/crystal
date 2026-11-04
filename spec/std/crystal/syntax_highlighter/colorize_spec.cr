require "crystal/syntax_highlighter/colorize"
require "spec"

private def it_highlights(code, expected, *, file = __FILE__, line = __LINE__)
  it code.inspect, file, line do
    highlighted = Crystal::SyntaxHighlighter::Colorize.highlight code
    highlighted.should eq(expected), file: file, line: line
    extracted_code = highlighted.gsub(/\e\[(?:\d+;)?\d+m/, "")
    extracted_code.should eq(code), file: file, line: line
  end
end

private def it_highlights!(code, expected = code, *, file = __FILE__, line = __LINE__)
  it code.inspect, file, line do
    highlighted = Crystal::SyntaxHighlighter::Colorize.highlight! code
    highlighted.should eq(expected), file: file, line: line
    extracted_code = highlighted.gsub(/\e\[(?:\d+;)?\d+m/, "")
    extracted_code.should eq(code), file: file, line: line

    no_colorized = String.build do |io|
      colorize = Crystal::SyntaxHighlighter::Colorize.new io, ::Colorize.with.toggle(false)
      colorize.highlight(code)
    end rescue code
    no_colorized.should eq(code), file: file, line: line
  end
end

private def assert_terminal_carriage_returns(rendered : Array(String), source : Array(String), *, file = __FILE__, line = __LINE__)
  source.each_with_index do |source_line, index|
    next unless source_line.ends_with?('\r')

    rendered[index].should end_with("\r"), file: file, line: line
    rendered[index].should_not contain("\r\e["), file: file, line: line
  end
end

describe Crystal::SyntaxHighlighter::Colorize do
  describe ".highlight" do
    it_highlights %(foo = bar("baz\#{PI + 1}") # comment), %(foo \e[91m=\e[39m bar(\e[93m"baz\#{\e[39m\e[36mPI\e[39m \e[91m+\e[39m \e[35m1\e[39m\e[93m}"\e[39m) \e[90m# comment\e[39m)

    it_highlights "foo", "foo"
    it_highlights "foo bar", "foo bar"
    it_highlights "foo\nbar", "foo\nbar"

    it_highlights "# foo", %(\e[90m# foo\e[39m)
    it_highlights "# bar\n", %(\e[90m# bar\e[39m\n)
    it_highlights "# foo\n# bar\n", %(\e[90m# foo\e[39m\n\e[90m# bar\e[39m\n)
    it_highlights %(# <">), %(\e[90m# <">\e[39m)

    it_highlights "42", %(\e[35m42\e[39m)
    it_highlights "3.14", %(\e[35m3.14\e[39m)
    it_highlights "123_i64", %(\e[35m123_i64\e[39m)

    it_highlights "'a'", %(\e[93m'a'\e[39m)
    it_highlights "'<'", %(\e[93m'<'\e[39m)

    it_highlights ":foo", %(\e[35m:foo\e[39m)
    it_highlights %(:"foo"), %(\e[35m:"foo"\e[39m)

    it_highlights "Foo", %(\e[36mFoo\e[39m)
    it_highlights "Foo::Bar", %(\e[36mFoo\e[39m\e[36m::\e[39m\e[36mBar\e[39m)

    %w(
      def if else elsif end class module include
      extend while until do yield return unless next break
      begin lib fun type struct union enum macro out require
      case when select then of rescue ensure is_a? alias sizeof alignof
      as as? typeof for in with super private asm
      nil? abstract pointerof
      protected uninitialized instance_sizeof instance_alignof offsetof
      annotation verbatim
    ).each do |kw|
      it_highlights kw, %(\e[91m#{kw}\e[39m)
    end

    it_highlights "self", %(\e[34mself\e[39m)

    %w(true false nil).each do |lit|
      it_highlights lit, %(\e[35m#{lit}\e[39m)
    end

    it_highlights "def foo", %(\e[91mdef\e[39m \e[92mfoo\e[39m)

    %w(
      [] []? []= <=>
      + - * /
      == < <= > >= != =~ !~
      & | ^ ~ ** >> << %
    ).each do |op|
      it_highlights %(def #{op}), %(\e[91mdef\e[39m \e[92m#{op}\e[39m)
    end

    it_highlights %(def //), %(\e[91mdef\e[39m \e[92m/\e[39m\e[92m/\e[39m)

    %w(
      + - * &+ &- &* &** / // = == < <= > >= ! != =~ !~ & | ^ ~ **
      >> << % [] []? []= <=> === && ||
      += -= *= /= //= &= |= ^= **= >>= <<= %= &+= &-= &*= &&= ||=
    ).each do |op|
      it_highlights "1 #{op} 2", %(\e[35m1\e[39m \e[91m#{op}\e[39m \e[35m2\e[39m)
    end

    it_highlights %(1/2), %(\e[35m1\e[39m\e[91m/\e[39m\e[35m2\e[39m)
    it_highlights %(1 /2), %(\e[35m1\e[39m \e[91m/\e[39m\e[35m2\e[39m)
    it_highlights %(1/ 2), %(\e[35m1\e[39m\e[91m/\e[39m \e[35m2\e[39m)

    it_highlights %(a/b), %(a\e[91m/\e[39mb)
    it_highlights %(a/ b), %(a\e[91m/\e[39m b)
    it_highlights %(a / b), %(a \e[91m/\e[39m b)

    it_highlights %(a /b/), %(a \e[93m/b/\e[39m)

    it_highlights %($1), %($1)
    it_highlights %($2?), %($2?)
    it_highlights %($?), %($?)
    it_highlights %($~), %($~)

    it_highlights %("foo"), %(\e[93m"foo"\e[39m)
    it_highlights %("<>"), %(\e[93m"<>"\e[39m)
    it_highlights %("foo\#{bar}baz"), %(\e[93m"foo\#{\e[39mbar\e[93m}baz"\e[39m)
    it_highlights %("foo\#{[1, bar, "str"]}baz"), %(\e[93m"foo\#{\e[39m[\e[35m1\e[39m, bar, \e[93m"str"\e[39m]\e[93m}baz"\e[39m)
    it_highlights %("nest1\#{foo + "nest2\#{1 + 1}bar"}baz"), %(\e[93m"nest1\#{\e[39mfoo \e[91m+\e[39m \e[93m"nest2\#{\e[39m\e[35m1\e[39m \e[91m+\e[39m \e[35m1\e[39m\e[93m}bar"\e[39m\e[93m}baz"\e[39m)
    it_highlights "/foo/xim", %(\e[93m/foo/\e[39mxim)
    it_highlights "`foo`", %(\e[93m`foo`\e[39m)
    it_highlights "%(foo)", %(\e[93m%(foo)\e[39m)
    it_highlights "%<foo>", %(\e[93m%<foo>\e[39m)
    it_highlights "%q(foo)", %(\e[93m%q(foo)\e[39m)
    it_highlights "%Q(foo)", %(\e[93m%Q(foo)\e[39m)
    it_highlights "%r(foo)xim", %(\e[93m%r(foo)\e[39mxim)
    it_highlights "%x(foo)", %(\e[93m%x(foo)\e[39m)

    it_highlights "%w(foo bar baz)", %(\e[93m%w(foo bar baz)\e[39m)
    it_highlights "%w(foo  bar\n  baz)", %(\e[93m%w(foo  bar\n  baz)\e[39m)
    it_highlights "%w<foo bar baz>", %(\e[93m%w<foo bar baz>\e[39m)
    it_highlights "%W(foo bar baz)", %(\e[93m%W(foo bar baz)\e[39m)
    it_highlights "%W(foo  bar\n  baz)", %(\e[93m%W(foo  bar\n  baz)\e[39m)
    it_highlights "%W(foo \#{bar} baz)", %(\e[93m%W(foo \#{\e[39mbar\e[93m} baz)\e[39m)
    it_highlights "%W(foo \#{*bar} baz)", %(\e[93m%W(foo \#{\e[39m\e[91m*\e[39mbar\e[93m} baz)\e[39m)
    it_highlights "%W(foo a\#{bar}b baz)", %(\e[93m%W(foo a\#{\e[39mbar\e[93m}b baz)\e[39m)
    it_highlights "%W(foo a\#{*bar}b baz)", %(\e[93m%W(foo a\#{\e[39m\e[91m*\e[39mbar\e[93m}b baz)\e[39m)
    it_highlights "%i(foo bar baz)", %(\e[93m%i(foo bar baz)\e[39m)

    it_highlights "Set{1, 2, 3}", %(\e[36mSet\e[39m{\e[35m1\e[39m, \e[35m2\e[39m, \e[35m3\e[39m})

    # Typed constant declarations (#13443)
    it_highlights "FOO : Int64 = 123", %(\e[36mFOO\e[39m : \e[36mInt64\e[39m \e[91m=\e[39m \e[35m123\e[39m)

    it_highlights "foo(/Name: /)", %(foo(\e[93m/Name: /\e[39m))
    it_highlights "foo[/Name: /]", %(foo[\e[93m/Name: /\e[39m])
    it_highlights "Foo{/Name: /}", %(\e[36mFoo\e[39m{\e[93m/Name: /\e[39m})

    it_highlights <<-CRYSTAL, <<-ANSI
      foo, bar = <<-FOO, <<-BAR
        foo
        FOO
        bar
        BAR
      CRYSTAL
      foo, bar \e[91m=\e[39m \e[93m<<-FOO\e[39m, \e[93m<<-BAR\e[39m
      \e[93m  foo
        FOO\e[39m
      \e[93m  bar
        BAR\e[39m
      ANSI
  end

  describe ".highlight!" do
    it_highlights! %(foo = bar("baz\#{PI + 1}") # comment), %(foo \e[91m=\e[39m bar(\e[93m"baz\#{\e[39m\e[36mPI\e[39m \e[91m+\e[39m \e[35m1\e[39m\e[93m}"\e[39m) \e[90m# comment\e[39m)

    it_highlights! <<-CRYSTAL
      foo, bar = <<-FOO, <<-BAR
        foo
        FOO
      CRYSTAL

    it_highlights! <<-CRYSTAL
      foo, bar = <<-FOO, <<-BAR
        foo
      CRYSTAL

    it_highlights! "\"foo"
    it_highlights! "%w[foo"
    it_highlights! "%i[foo"
  end

  describe ".highlight_lines!" do
    it "highlights physical lines independently" do
      source = ["foo = <<-TXT", "body", "TXT", "bar = 1"]
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source)

      highlighted.should eq([
        "foo \e[91m=\e[39m \e[93m<<-TXT\e[39m",
        "\e[93mbody\e[39m",
        "\e[93mTXT\e[39m",
        "bar \e[91m=\e[39m \e[35m1\e[39m",
      ])
      highlighted.map { |line| line.gsub(/\e\[[0-9;]*m/, "") }.should eq(source)

      Crystal::SyntaxHighlighter::Colorize.highlight_lines!(%(answer = 42 + "two")).should eq([
        %(answer \e[91m=\e[39m \e[35m42\e[39m \e[91m+\e[39m \e[93m"two"\e[39m),
      ])
    end

    it "stops after an inclusive line boundary" do
      source = ["foo = <<-TXT", "body", "still unterminated"]
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source, 1)

      highlighted.should eq([
        "foo \e[91m=\e[39m \e[93m<<-TXT\e[39m",
        "\e[93mbody\e[39m",
        "still unterminated",
      ])
    end

    it "does not let a malformed suffix suppress a bounded result" do
      source = ["foo = 1", "bar = 2", "broken = \""]
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source, 1)

      highlighted[0].should contain("\e[35m1\e[39m")
      highlighted[1].should contain("\e[35m2\e[39m")
      highlighted[2].should eq(source[2])
    end

    it "isolates fallback after a lexer error" do
      source = ["bad = \"unterminated", "answer = 42"]
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source)

      highlighted[1].should eq("answer \e[91m=\e[39m \e[35m42\e[39m")
    end

    it "preserves literal escapes and fully resets their terminal state" do
      literal_escape = "\e[44;1m"
      source = ["foo = <<-TXT", "body #{literal_escape}", "TXT"]
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source)

      highlighted[1].should contain(literal_escape)
      highlighted[1].should end_with("\e[0m")
      highlighted[2].should eq("\e[93mTXT\e[39m")

      uncolored = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(["plain#{literal_escape}", "following"])
      uncolored[0].should contain(literal_escape)
      uncolored[0].should end_with("\e[0m")
      uncolored[1].should eq("following")
    end

    it "fully restores a base background and mode on each line" do
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(
        "1\n2",
        colorize: ::Colorize.with.on_blue.bold.toggle(true)
      )

      highlighted.should eq([
        "\e[35;44;1m1\e[39;49;22m",
        "\e[35;44;1m2\e[39;49;22m",
      ])

      Crystal::SyntaxHighlighter::Colorize.highlight_lines!(
        %("x\#{foo}"),
        colorize: ::Colorize.with.on_blue.bold.toggle(true)
      ).should eq([
        %(\e[93;44;1m"x\#{\e[39;49;22m\e[44;1mfoo\e[49;22m\e[93;44;1m}"\e[39;49;22m),
      ])
    end

    it "does not emit escapes when its base style is disabled" do
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(
        "1\n2",
        colorize: ::Colorize.with.toggle(false)
      )

      highlighted.should eq(["1", "2"])
    end

    it "preserves CRLF bytes in normal and fallback rendering" do
      sources = [
        "answer = 1\r\nnext = 2\r\n",
        "bad = \"unterminated\r\nanswer = 42\r",
      ]

      sources.each do |source|
        source_lines = source.split('\n', remove_empty: false)

        rendered = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source)
        rendered.map { |line| line.gsub(/\e\[[0-9;]*m/, "") }.join('\n').should eq(source)
        assert_terminal_carriage_returns(rendered, source_lines)

        rendered = Crystal::SyntaxHighlighter::Colorize.highlight_lines!(source_lines)
        rendered.map { |line| line.gsub(/\e\[[0-9;]*m/, "") }.should eq(source_lines)
        assert_terminal_carriage_returns(rendered, source_lines)
      end

      literal_escape = "\e[44;1m"
      rendered = Crystal::SyntaxHighlighter::Colorize.highlight_lines!([
        "foo = <<-TXT\r",
        "body #{literal_escape}\r",
        "TXT\r",
      ])
      rendered[1].should end_with("\e[0m\r")
      rendered[2].should eq("\e[93mTXT\e[39m\r")
    end

    it "restores a styled base after a literal escape on the previous line" do
      literal_escape = "\e[44;1m"
      highlighted = Crystal::SyntaxHighlighter::Colorize.highlight_lines!([
        "foo = <<-TXT",
        "body #{literal_escape}",
        "TXT",
      ], colorize: ::Colorize.with.red.on_blue.bold.toggle(true))

      highlighted[1].should contain(literal_escape)
      highlighted[1].should end_with("\e[0m")
      highlighted[2].should eq("\e[93;44;1mTXT\e[39;49;22m")
    end
  end
end
