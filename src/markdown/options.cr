module Markdown
  struct Options
    property smart, source_pos, safe, prettyprint

    def initialize(
      @smart = false,
      @source_pos = false,
      @safe = false,
      @prettyprint = false
    )
    end
  end
end
