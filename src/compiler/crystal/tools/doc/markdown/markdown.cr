# Basic implementation of Markdown for the `crystal doc` tool.
#
# It lacks many features and it has some bugs too. Eventually we should replace
# it with something more feature-complete (like https://github.com/icyleaf/markd)
# but that means the compiler will start depending on external shards. Otherwise
# we should extract the doc as a separate tool/binary.
# We don't expose this library in the standard library because it's probable
# that we will never make it feature complete.
#
# Usage:
#
# ```
# require "compiler/crystal/tools/doc/markdown"
#
# text = "## This is title \n This is a [link](https://crystal-lang.org)"
#
# Crystal::Doc::Markdown.to_html(text)
# # => <h2>This is title</h2>
# # => <p>This is a <a href="https://crystal-lang.org">link</a></p>
# ```
module Crystal::Doc::Markdown
  def self.parse(text, renderer)
    parser = Parser.new(text, renderer)
    parser.parse
  end

  def self.to_html(text) : String
    String.build do |io|
      parse text, Markdown::HTMLRenderer.new(io)
    end
  end
end

require "./parser"
require "./renderer"
require "./html_renderer"
