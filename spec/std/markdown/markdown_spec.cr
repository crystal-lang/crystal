require "spec"
require "markdown"

def assert_render(input, output, file = __FILE__, line = __LINE__)
  it "renders #{input.inspect}", file, line do
    Markdown.to_html(input).should eq(output)
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

  assert_render "    Hello", "<pre><code>Hello</code></pre>"
  assert_render "    Hello\n    World", "<pre><code>Hello\nWorld</code></pre>"
  assert_render "    Hello\n\n    World", "<pre><code>Hello\n\nWorld</code></pre>"
  assert_render "    Hello\n\n   \n    World", "<pre><code>Hello\n\n\nWorld</code></pre>"
  assert_render "    Hello\n   World", "<pre><code>Hello</code></pre>\n\n<p>World</p>"
  assert_render "    Hello\n\n\nWorld", "<pre><code>Hello</code></pre>\n\n<p>World</p>"

  assert_render "```crystal\nHello\nWorld\n```", "<pre><code>Hello\nWorld\n</code></pre>"

  assert_render "* Hello", "<ul><li>Hello</li></ul>"
  assert_render "* Hello\n* World", "<ul><li>Hello</li><li>World</li></ul>"
  assert_render "* Hello\nWorld", "<ul><li>Hello</li></ul>\n\n<p>World</p>"
  assert_render "Params:\n  * Foo\n  * Bar", "<p>Params:</p>\n\n<ul><li>Foo</li><li>Bar</li></ul>"

  assert_render "Hello [world](http://foo.com)", %(<p>Hello <a href="http://foo.com">world</a></p>)
  assert_render "Hello [world](http://foo.com)!", %(<p>Hello <a href="http://foo.com">world</a>!</p>)
  assert_render "Hello [world **2**](http://foo.com)!", %(<p>Hello <a href="http://foo.com">world <strong>2</strong></a>!</p>)

  assert_render "Hello ![world](http://foo.com)", %(<p>Hello <img src="http://foo.com" alt="world"/></p>)
  assert_render "Hello ![world](http://foo.com)!", %(<p>Hello <img src="http://foo.com" alt="world"/>!</p>)

  assert_render "[![foo](bar)](baz)", %(<p><a href="baz"><img src="bar" alt="foo"/></a></p>)
end
