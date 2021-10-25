require "../syntax_highlighter"

class Crystal::SyntaxHighlighter
  class HTML < Crystal::SyntaxHighlighter
    def initialize(@io : IO)
    end

    def render(type : TokenType, value : String)
      case type
      when .comment?
        span "c" { ::HTML.escape(value, @io) }
      when .number?
        span "n", &.print value
      when .char?
        span "s" { ::HTML.escape(value, @io) }
      when .symbol?
        span "n" { ::HTML.escape(value, @io) }
      when .const?
        span "t", &.print value
      when .string?
        span "s" { ::HTML.escape(value, @io) }
      when .ident?
        span "m", &.print value
      when .keyword?, .self?
        span "k", &.print value
      when .primitive_literal?
        span "n", &.print value
      when .operator?
        span "o" { ::HTML.escape(value, @io) }
      else
        ::HTML.escape(value, @io)
      end
    end

    def render_delimiter(&)
      span "s" do
        yield
      end
    end

    def render_interpolation(&)
      span_end
      span "i", &.print "\#{"
      yield
      span "i", &.print "}"
      span_start "s"
    end

    def render_string_array(&)
      span "s" do
        yield
      end
    end

    private def span(klass, &)
      span_start klass
      yield @io
      span_end
    end

    private def span_start(klass)
      @io << %(<span class=")
      @io << klass
      @io << %(">)
    end

    private def span_end
      @io << %(</span>)
    end
  end
end
