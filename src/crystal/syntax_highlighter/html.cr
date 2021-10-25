require "../syntax_highlighter"

class Crystal::SyntaxHighlighter::HTML < Crystal::SyntaxHighlighter
  def initialize(@io : IO)
  end

  def render(type : TokenType, value)
    case type
    when .comment?
      span "c", ::HTML.escape(value)
    when .number?
      span "n", value
    when .char?
      span "s", ::HTML.escape(value)
    when .symbol?
      span "n", ::HTML.escape(value)
    when .const?
      span "t", value
    when .string?
      span "s", ::HTML.escape(value)
    when .ident?
      span "m", value
    when .keyword?, .self?
      span "k", value
    when .primitive_literal?
      span "n", value
    when .operator?
      span "o", ::HTML.escape(value)
    else
      ::HTML.escape(value, @io)
    end
  end

  def visit_delimiter(&)
    span_start "s"
    yield
    span_end
  end

  def visit_interpolation(&)
    span_end
    span "i", "\#{"
    yield
    span "i", "}"
    span_start "s"
  end

  def visit_string_array(&)
    span_start "s"
    yield
    span_end
  end

  private def span(klass, token)
    span_start klass
    @io << token
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
