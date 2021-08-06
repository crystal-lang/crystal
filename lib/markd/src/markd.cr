require "./markd/html_entities"
require "./markd/utils"
require "./markd/node"
require "./markd/rule"
require "./markd/options"
require "./markd/renderer"
require "./markd/parser"
require "./markd/version"

module Markd
  def self.to_html(source : String, options = Options.new)
    return "" if source.empty?

    document = Parser.parse(source, options)
    renderer = HTMLRenderer.new(options)
    renderer.render(document)
  end
end
