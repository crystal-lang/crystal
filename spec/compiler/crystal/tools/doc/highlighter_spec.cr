require "xml"
require "html"
require "../../../../spec_helper"

private def it_highlights(code, expected, file = __FILE__, line = __LINE__)
  it "highlights #{code.inspect}", file, line do
    highlighted = Crystal::Doc::Highlighter.highlight code
    highlighted.should eq(expected), file, line
    doc = XML.parse_html highlighted
    doc.content.should eq(code), file, line
  end
end

describe "Crystal::Doc::Highlighter#highlight" do
  it_highlights "foo", "foo"
  it_highlights "foo bar", "foo bar"
  it_highlights "foo\nbar", "foo\nbar"

  it_highlights "# foo", %(<span class="c"># foo</span>)
  it_highlights "# bar\n", %(<span class="c"># bar</span>\n)
  it_highlights "# foo\n# bar\n", %(<span class="c"># foo</span>\n<span class="c"># bar</span>\n)
  it_highlights %(# <">), %(<span class="c"># &lt;&quot;&gt;</span>)

  it_highlights "42", %(<span class="n">42</span>)
  it_highlights "3.14", %(<span class="n">3.14</span>)
  it_highlights "123_i64", %(<span class="n">123_i64</span>)

  it_highlights "'a'", %(<span class="s">&#39;a&#39;</span>)
  it_highlights "'<'", %(<span class="s">&#39;&lt;&#39;</span>)

  it_highlights ":foo", %(<span class="n">:foo</span>)
  it_highlights %(:"foo"), %(<span class="n">:&quot;foo&quot;</span>)

  it_highlights "Foo", %(<span class="t">Foo</span>)
  it_highlights "Foo::Bar", %(<span class="t">Foo</span><span class="t">::</span><span class="t">Bar</span>)

  %w(
    def if else elsif end class module include
    extend while until do yield return unless next break
    begin lib fun type struct union enum macro out require
    case when select then of rescue ensure is_a? alias sizeof
    as as? typeof for in with self super private asm
    nil? abstract pointerof
    protected uninitialized instance_sizeof
    annotation verbatim
  ).each do |kw|
    it_highlights kw, %(<span class="k">#{kw}</span>)
  end

  %w(true false nil).each do |lit|
    it_highlights lit, %(<span class="n">#{lit}</span>)
  end

  it_highlights "def foo", %(<span class="k">def</span> <span class="m">foo</span>)

  %w(
    + - * / = == < <= > >= ! != =~ !~ & | ^ ~ **
    >> << % [] []? []= <=> ===
  ).each do |op|
    it_highlights "1 #{op} 2", %(<span class="n">1</span> <span class="o">#{HTML.escape(op)}</span> <span class="n">2</span>)
  end

  it_highlights %("foo"), %(<span class="s">&quot;foo&quot;</span>)
  it_highlights %("<>"), %(<span class="s">&quot;&lt;&gt;&quot;</span>)
  it_highlights %("foo\#{bar}baz"), %(<span class="s">&quot;foo</span><span class="i">\#{</span>bar<span class="i">}</span><span class="s">baz&quot;</span>)
  it_highlights "/foo/xim", %(<span class="s">/foo/</span>xim)
  it_highlights "`foo`", %(<span class="s">`foo`</span>)
  it_highlights "%(foo)", %(<span class="s">%(foo)</span>)
  it_highlights "%<foo>", %(<span class="s">%&lt;foo&gt;</span>)
  it_highlights "%q(foo)", %(<span class="s">%q(foo)</span>)
  it_highlights "%Q(foo)", %(<span class="s">%Q(foo)</span>)
  it_highlights "%r(foo)xim", %(<span class="s">%r(foo)</span>xim)
  it_highlights "%x(foo)", %(<span class="s">%x(foo)</span>)

  it_highlights "%w(foo bar baz)", %(<span class="s">%w(foo bar baz)</span>)
  it_highlights "%w(foo  bar\n  baz)", %(<span class="s">%w(foo  bar\n  baz)</span>)
  it_highlights "%w<foo bar baz>", %(<span class="s">%w&lt;foo bar baz&gt;</span>)
  it_highlights "%i(foo bar baz)", %(<span class="s">%i(foo bar baz)</span>)
end
