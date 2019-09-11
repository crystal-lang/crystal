require "./html_entities"
require "./utils"
require "./node"
require "./rule"
require "./options"
require "./renderer"
require "./parser"
require "./version"

# Author: https://github.com/icyleaf
module Crystal::Doc::Markdown
  def self.to_html(source : String, options = Options.new) : String
    return "" if source.empty?

    document = Parser.parse(source, options)
    renderer = HTMLRenderer.new(options)
    renderer.render(document)
  end
end
