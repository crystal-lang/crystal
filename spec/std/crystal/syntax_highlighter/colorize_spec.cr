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

describe Crystal::SyntaxHighlighter::Colorize do
  describe ".highlight" do
    it_highlights %(foo = bar("baz\#{PI + 1}") # comment), %(foo \e[91m=\e[0m bar(\e[93m"baz\#{\e[0m\e[36mPI\e[0m \e[91m+\e[0m \e[35m1\e[0m\e[93m}"\e[0m) \e[90m# comment\e[0m)

    it_highlights "foo", "foo"
    it_highlights "foo bar", "foo bar"
    it_highlights "foo\nbar", "foo\nbar"

    it_highlights "# foo", %(\e[90m# foo\e[0m)
    it_highlights "# bar\n", %(\e[90m# bar\e[0m\n)
    it_highlights "# foo\n# bar\n", %(\e[90m# foo\e[0m\n\e[90m# bar\e[0m\n)
    it_highlights %(# <">), %(\e[90m# <">\e[0m)

    it_highlights "42", %(\e[35m42\e[0m)
    it_highlights "3.14", %(\e[35m3.14\e[0m)
    it_highlights "123_i64", %(\e[35m123_i64\e[0m)

    it_highlights "'a'", %(\e[93m'a'\e[0m)
    it_highlights "'<'", %(\e[93m'<'\e[0m)

    it_highlights ":foo", %(\e[35m:foo\e[0m)
    it_highlights %(:"foo"), %(\e[35m:"foo"\e[0m)

    it_highlights "Foo", %(\e[36mFoo\e[0m)
    it_highlights "Foo::Bar", %(\e[36mFoo\e[0m\e[36m::\e[0m\e[36mBar\e[0m)

    %w(
      def if else elsif end class module include
      extend while until do yield return unless next break
      begin lib fun type struct union enum macro out require
      case when select then of rescue ensure is_a? alias sizeof
      as as? typeof for in with super private asm
      nil? abstract pointerof
      protected uninitialized instance_sizeof offsetof
      annotation verbatim
    ).each do |kw|
      it_highlights kw, %(\e[91m#{kw}\e[0m)
    end

    it_highlights "self", %(\e[34mself\e[0m)

    %w(true false nil).each do |lit|
      it_highlights lit, %(\e[35m#{lit}\e[0m)
    end

    it_highlights "def foo", %(\e[91mdef\e[0m \e[92mfoo\e[0m)

    %w(
      [] []? []= <=>
      + - * /
      == < <= > >= != =~ !~
      & | ^ ~ ** >> << %
    ).each do |op|
      it_highlights %(def #{op}), %(\e[91mdef\e[0m \e[92m#{op}\e[0m)
    end

    it_highlights %(def //), %(\e[91mdef\e[0m \e[92m/\e[0m\e[92m/\e[0m)

    %w(
      + - * &+ &- &* &** / // = == < <= > >= ! != =~ !~ & | ^ ~ **
      >> << % [] []? []= <=> === && ||
      += -= *= /= //= &= |= ^= **= >>= <<= %= &+= &-= &*= &&= ||=
    ).each do |op|
      it_highlights "1 #{op} 2", %(\e[35m1\e[0m \e[91m#{op}\e[0m \e[35m2\e[0m)
    end

    it_highlights %(1/2), %(\e[35m1\e[0m\e[91m/\e[0m\e[35m2\e[0m)
    it_highlights %(1 /2), %(\e[35m1\e[0m \e[91m/\e[0m\e[35m2\e[0m)
    it_highlights %(1/ 2), %(\e[35m1\e[0m\e[91m/\e[0m \e[35m2\e[0m)

    it_highlights %(a/b), %(a\e[91m/\e[0mb)
    it_highlights %(a/ b), %(a\e[91m/\e[0m b)
    it_highlights %(a / b), %(a \e[91m/\e[0m b)

    it_highlights %(a /b/), %(a \e[93m/b/\e[0m)

    it_highlights %($1), %($1)
    it_highlights %($2?), %($2?)
    it_highlights %($?), %($?)
    it_highlights %($~), %($~)

    it_highlights %("foo"), %(\e[93m"foo"\e[0m)
    it_highlights %("<>"), %(\e[93m"<>"\e[0m)
    it_highlights %("foo\#{bar}baz"), %(\e[93m"foo\#{\e[0mbar\e[93m}baz"\e[0m)
    it_highlights %("foo\#{[1, bar, "str"]}baz"), %(\e[93m"foo\#{\e[0m[\e[35m1\e[0m, bar, \e[93m"str"\e[0m]\e[93m}baz"\e[0m)
    it_highlights %("nest1\#{foo + "nest2\#{1 + 1}bar"}baz"), %(\e[93m"nest1\#{\e[0mfoo \e[91m+\e[0m \e[93m"nest2\#{\e[0m\e[35m1\e[0m \e[91m+\e[0m \e[35m1\e[0m\e[93m}bar"\e[0m\e[93m}baz"\e[0m)
    it_highlights "/foo/xim", %(\e[93m/foo/\e[0mxim)
    it_highlights "`foo`", %(\e[93m`foo`\e[0m)
    it_highlights "%(foo)", %(\e[93m%(foo)\e[0m)
    it_highlights "%<foo>", %(\e[93m%<foo>\e[0m)
    it_highlights "%q(foo)", %(\e[93m%q(foo)\e[0m)
    it_highlights "%Q(foo)", %(\e[93m%Q(foo)\e[0m)
    it_highlights "%r(foo)xim", %(\e[93m%r(foo)\e[0mxim)
    it_highlights "%x(foo)", %(\e[93m%x(foo)\e[0m)

    it_highlights "%w(foo bar baz)", %(\e[93m%w(foo bar baz)\e[0m)
    it_highlights "%w(foo  bar\n  baz)", %(\e[93m%w(foo  bar\n  baz)\e[0m)
    it_highlights "%w<foo bar baz>", %(\e[93m%w<foo bar baz>\e[0m)
    it_highlights "%i(foo bar baz)", %(\e[93m%i(foo bar baz)\e[0m)

    it_highlights "Set{1, 2, 3}", %(\e[36mSet\e[0m{\e[35m1\e[0m, \e[35m2\e[0m, \e[35m3\e[0m})

    it_highlights <<-CRYSTAL, <<-ANSI
      foo, bar = <<-FOO, <<-BAR
        foo
        FOO
        bar
        BAR
      CRYSTAL
      foo, bar \e[91m=\e[0m \e[93m<<-FOO\e[0m, \e[93m<<-BAR\e[0m
      \e[93m  foo
        FOO\e[0m
      \e[93m  bar
        BAR\e[0m
      ANSI
  end

  describe ".highlight!" do
    it_highlights! %(foo = bar("baz\#{PI + 1}") # comment), %(foo \e[91m=\e[0m bar(\e[93m"baz\#{\e[0m\e[36mPI\e[0m \e[91m+\e[0m \e[35m1\e[0m\e[93m}"\e[0m) \e[90m# comment\e[0m)

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
end
