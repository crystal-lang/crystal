require "spec"
require "../../support/iterate"

def it_iterates_graphemes(string, graphemes)
  graphemes = graphemes.map { |grapheme| String::Grapheme.new(grapheme) }

  it_iterates string.dump, graphemes, string.each_grapheme
end
