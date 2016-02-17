# Markdown library parses Markdown text. It supports rendering to HTML text.
# Note: This library is in its early stage. Many features are still in development.
#
# Usage:
#
#     require "markdown"
#
#     text = "## This is title \n This is a [link](http://crystal-lang.org)"
#
#     Markdown.to_html(text)
#     #=><h2>This is title</h2>
#     #=><p>This is a <a href="http://crystal-lang.org">link</a></p>
class Markdown
  def self.parse(text, renderer)
    parser = Parser.new(text, renderer)
    parser.parse
  end

  def self.to_html(text)
    String.build do |io|
      parse text, Markdown::HTMLRenderer.new(io)
    end
  end
end

require "./*"
