require "spec"
require "spec/helpers/iterate"

def it_iterates_graphemes(string, graphemes, *, file = __FILE__, line = __LINE__)
  graphemes = graphemes.map { |grapheme| String::Grapheme.new(grapheme) }

  it_iterates string.dump, graphemes, string.each_grapheme, file: file, line: line
end
