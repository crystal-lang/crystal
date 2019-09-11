require "./markdown/html_entities"
require "./markdown/utils"
require "./markdown/node"
require "./markdown/rule"
require "./markdown/options"
require "./markdown/renderer"
require "./markdown/parser"
require "./markdown/version"

# Implementation of [Markdown](https://en.wikipedia.org/wiki/Markdown).
#
# Usage:
#
# ```
# require "markdown"
#
# text = "## This is title \n This is a [link](http://crystal-lang.org)"
#
# Markdown.to_html(text)
# # => <h2>This is title</h2>
# # => <p>This is a <a href="http://crystal-lang.org">link</a></p>
# ```
#
# Author: https://github.com/icyleaf
module Markdown
  # Converts the given Markdown source into an HTML string.
  def self.to_html(source : String, options = Options.new) : String
    return "" if source.empty?

    document = Parser.parse(source, options)
    renderer = HTMLRenderer.new(options)
    renderer.render(document)
  end
end
