require "spec"
require "markdown"

private def assert_render(input, output, file = __FILE__, line = __LINE__)
  it "renders #{input.inspect}", file, line do
    Markdown.to_html(input).should eq(output), file, line
  end
end

describe Markdown do
  assert_render "", ""
  assert_render "Hello", "<p>Hello</p>"
  assert_render "Hello\nWorld", "<p>Hello\nWorld</p>"
  assert_render "Hello\n\nWorld", "<p>Hello</p>\n\n<p>World</p>"
  assert_render "Hello\n\n\n\n\nWorld", "<p>Hello</p>\n\n<p>World</p>"
  assert_render "Hello\n  \nWorld", "<p>Hello</p>\n\n<p>World</p>"
  assert_render "Hello\nWorld\n\nGood\nBye", "<p>Hello\nWorld</p>\n\n<p>Good\nBye</p>"

  assert_render "*Hello*", "<p><em>Hello</em></p>"
  assert_render "*Hello", "<p>*Hello</p>"
  assert_render "*Hello *", "<p>*Hello *</p>"
  assert_render "*Hello World*", "<p><em>Hello World</em></p>"
  assert_render "これは　*みず* です", "<p>これは　<em>みず</em> です</p>"

  assert_render "**Hello**", "<p><strong>Hello</strong></p>"
  assert_render "**Hello **", "<p>**Hello **</p>"

  assert_render "_Hello_", "<p><em>Hello</em></p>"
  assert_render "_Hello", "<p>_Hello</p>"
  assert_render "_Hello _", "<p>_Hello _</p>"
  assert_render "_Hello World_", "<p><em>Hello World</em></p>"

  assert_render "__Hello__", "<p><strong>Hello</strong></p>"
  assert_render "__Hello __", "<p>__Hello __</p>"

  assert_render "this_is_not_italic", "<p>this_is_not_italic</p>"
  assert_render "this__is__not__bold", "<p>this__is__not__bold</p>"

  assert_render "`Hello`", "<p><code>Hello</code></p>"

  assert_render "Hello\n=", "<h1>Hello</h1>"
  assert_render "Hello\n===", "<h1>Hello</h1>"
  assert_render "Hello\n===\nWorld", "<h1>Hello</h1>\n\n<p>World</p>"
  assert_render "Hello\n===World", "<p>Hello\n===World</p>"

  assert_render "Hello\n-", "<h2>Hello</h2>"
  assert_render "Hello\n-", "<h2>Hello</h2>"
  assert_render "Hello\n-World", "<p>Hello\n-World</p>"

  assert_render "#Hello", "<h1>Hello</h1>"
  assert_render "# Hello", "<h1>Hello</h1>"
  assert_render "#    Hello", "<h1>Hello</h1>"
  assert_render "## Hello", "<h2>Hello</h2>"
  assert_render "### Hello", "<h3>Hello</h3>"
  assert_render "#### Hello", "<h4>Hello</h4>"
  assert_render "##### Hello", "<h5>Hello</h5>"
  assert_render "###### Hello", "<h6>Hello</h6>"
  assert_render "####### Hello", "<h6># Hello</h6>"

  assert_render "# Hello\nWorld", "<h1>Hello</h1>\n\n<p>World</p>"
  assert_render "# Hello\n---", "<h1>Hello</h1>\n\n<hr/>"

  assert_render "    Hello", "<pre><code>Hello</code></pre>"
  assert_render "    Hello\n    World", "<pre><code>Hello\nWorld</code></pre>"
  assert_render "    Hello\n\n    World", "<pre><code>Hello\n\nWorld</code></pre>"
  assert_render "    Hello\n\n   \n    World", "<pre><code>Hello\n\n\nWorld</code></pre>"
  assert_render "    Hello\n   World", "<pre><code>Hello</code></pre>\n\n<p>World</p>"
  assert_render "    Hello\n\n\nWorld", "<pre><code>Hello</code></pre>\n\n<p>World</p>"

  assert_render "```crystal\nHello\nWorld\n```", "<pre><code class='language-crystal'>Hello\nWorld</code></pre>"
  assert_render "Hello\n```\nWorld\n```", "<p>Hello</p>\n\n<pre><code>World</code></pre>"
  assert_render "```\n---\n```", "<pre><code>---</code></pre>"

  assert_render "> Hello World\n", "<blockquote>Hello World</blockquote>"
  assert_render "> __Hello World__", "<blockquote><strong>Hello World</strong></blockquote>"
  assert_render "> This spawns\nmultiple\nlines\n\ntext", "<blockquote>This spawns\nmultiple\nlines</blockquote>\n\n<p>text</p>"

  assert_render "* Hello", "<ul><li>Hello</li></ul>"
  assert_render "* Hello\n* World", "<ul><li>Hello</li><li>World</li></ul>"
  assert_render "* Hello\n* World\n  * Crystal", "<ul><li>Hello</li><li>World</li><ul><li>Crystal</li></ul></ul>"
  assert_render "* Level1\n  * Level2\n  * Level2\n* Level1", "<ul><li>Level1</li><ul><li>Level2</li><li>Level2</li></ul><li>Level1</li></ul>"
  assert_render "* Level1\n  * Level2\n  * Level2", "<ul><li>Level1</li><ul><li>Level2</li><li>Level2</li></ul></ul>"
  assert_render "* Hello\nWorld", "<ul><li>Hello\nWorld</li></ul>"
  assert_render "Params:\n* Foo\n* Bar", "<p>Params:</p>\n\n<ul><li>Foo</li><li>Bar</li></ul>"

  assert_render "* Hello\n* World\n\n```\nHello World\n```", "<ul><li>Hello</li><li>World</li></ul>\n\n<pre><code>Hello World</code></pre>"
  assert_render "1. Hello\n2. World\n\n```\nHello World\n```", "<ol><li>Hello</li><li>World</li></ol>\n\n<pre><code>Hello World</code></pre>"

  assert_render "+ Hello", "<ul><li>Hello</li></ul>"
  assert_render "- Hello", "<ul><li>Hello</li></ul>"

  assert_render "* Hello\n+ World\n- Crystal", "<ul><li>Hello</li></ul>\n\n<ul><li>World</li></ul>\n\n<ul><li>Crystal</li></ul>"

  assert_render "* This spawns\nmultiple\nlines\n\ntext", "<ul><li>This spawns\nmultiple\nlines</li></ul>\n\n<p>text</p>"
  assert_render "* Two\nlines\n* This spawns\nmultiple\nlines\n\ntext", "<ul><li>Two\nlines</li><li>This spawns\nmultiple\nlines</li></ul>\n\n<p>text</p>"

  assert_render "1. Hello", "<ol><li>Hello</li></ol>"
  assert_render "2. Hello", "<ol><li>Hello</li></ol>"
  assert_render "01. Hello\n02. World", "<ol><li>Hello</li><li>World</li></ol>"
  assert_render "Params:\n  1. Foo\n  2. Bar", "<p>Params:</p>\n\n<ol><li>Foo</li><li>Bar</li></ol>"

  assert_render "1. This spawns\nmultiple\nlines\n\ntext", "<ol><li>This spawns\nmultiple\nlines</li></ol>\n\n<p>text</p>"
  assert_render "1. Two\nlines\n1. This spawns\nmultiple\nlines\n\ntext", "<ol><li>Two\nlines</li><li>This spawns\nmultiple\nlines</li></ol>\n\n<p>text</p>"

  assert_render "Hello [world](http://example.com)", %(<p>Hello <a href="http://example.com">world</a></p>)
  assert_render "Hello [world](http://example.com)!", %(<p>Hello <a href="http://example.com">world</a>!</p>)
  assert_render "Hello [world **2**](http://example.com)!", %(<p>Hello <a href="http://example.com">world <strong>2</strong></a>!</p>)

  assert_render "Hello ![world](http://example.com)", %(<p>Hello <img src="http://example.com" alt="world"/></p>)
  assert_render "Hello ![world](http://example.com)!", %(<p>Hello <img src="http://example.com" alt="world"/>!</p>)

  assert_render "[![foo](bar)](baz)", %(<p><a href="baz"><img src="bar" alt="foo"/></a></p>)

  assert_render "This [spawns\nmultiple\nlines](http://example.com)\n\ntext",
    %(<p>This <a href="http://example.com">spawns\nmultiple\nlines</a></p>\n\n<p>text</p>)

  assert_render "***", "<hr/>"
  assert_render "---", "<hr/>"
  assert_render "___", "<hr/>"
  assert_render "  *  *  *  ", "<hr/>"

  assert_render "hello < world", "<p>hello &lt; world</p>"

  assert_render "Hello __[World](http://example.com)__!", %(<p>Hello <strong><a href="http://example.com">World</a></strong>!</p>)
end
