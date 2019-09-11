module Markdown
  struct Options
    property toc, smart, source_pos, safe, prettyprint

    def initialize(
      @toc = false,
      @smart = false,
      @source_pos = false,
      @safe = false,
      @prettyprint = false
    )
    end
  end
end
