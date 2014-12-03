require "spec"
require "markdown"

module Markdown
  def self.expect_html(input, output)
    it "renders markdown #{input.inspect}" do
      render_html(input).should eq(output)
    end
  end

  describe "Markdown" do
    expect_html "Hello", "<p>Hello</p>"
    expect_html "Hello\nWorld", "<p>Hello\nWorld</p>"
    expect_html "Hello\n\nWorld", "<p>Hello</p>\n<p>World</p>"
    expect_html "Hello\n\n\n\n\nWorld", "<p>Hello</p>\n<p>World</p>"
    expect_html "Hello *world*", "<p>Hello <em>world</em></p>"
    expect_html "Hello _world_", "<p>Hello <em>world</em></p>"
    expect_html "Hello *world", "<p>Hello *world</p>"
    expect_html "Hello *world\nBye *world", "<p>Hello *world\nBye *world</p>"
    expect_html "Hello * world *", "<p>Hello * world *</p>"
    expect_html "Hello **world**", "<p>Hello <strong>world</strong></p>"
    expect_html "Hello __world__", "<p>Hello <strong>world</strong></p>"
    expect_html "Hello **world", "<p>Hello **world</p>"
    expect_html "Hello **world\nBye **world", "<p>Hello **world\nBye **world</p>"
    expect_html "Hello `world`", "<p>Hello <code>world</code></p>"
    expect_html "Hello `world`\nBye `world`", "<p>Hello <code>world</code>\nBye <code>world</code></p>"
    expect_html "Hello `world", "<p>Hello `world</p>"
    expect_html "Hello *`world`*", "<p>Hello <em><code>world</code></em></p>"
    expect_html "Hello *`world`", "<p>Hello *<code>world</code></p>"

    1.upto(6) do |count|
      expect_html "#{"#" * count} Hello", "<h#{count}>Hello</h#{count}>"
    end
    expect_html "####### Hello", "<h6># Hello</h6>"
    # expect_html "# One\n# Two", "<h1>One</h1>\n<h1>Two</h1>"
  end
end
