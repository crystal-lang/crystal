require "./markd/html_entities"
require "./markd/utils"
require "./markd/node"
require "./markd/rule"
require "./markd/options"
require "./markd/renderer"
require "./markd/parser"
require "./markd/version"

module Markd
  {% if @top_level.has_constant?("Tartrazine") %}
    def self.to_html(
      source : String,
      options = Options.new,
      *,
      formatter : Tartrazine::Formatter | String = "catppuccin-macchiato",
    )
      return "" if source.empty?

      if formatter.is_a?(String)
        formatter = Tartrazine::Html.new(
          theme: Tartrazine.theme(formatter),
          line_numbers: true,
          standalone: true,
        )
      end

      document = Parser.parse(source, options)
      renderer = HTMLRenderer.new(options)
      renderer.render(document, formatter)
    end
  {% else %}
    def self.to_html(
      source : String,
      options = Options.new,
      formatter = nil,
    )
      return "" if source.empty?

      document = Parser.parse(source, options)
      renderer = HTMLRenderer.new(options)
      renderer.render(document, formatter)
    end
  {% end %}
end
