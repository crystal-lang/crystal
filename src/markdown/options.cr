module Markdown
  struct Options
    property time, gfm, toc, smart, source_pos, safe, prettyprint

    def initialize(
      @time = false,
      @gfm = false,
      @toc = false,
      @smart = false,
      @source_pos = false,
      @safe = false,
      @prettyprint = false
    )
    end
  end
end
