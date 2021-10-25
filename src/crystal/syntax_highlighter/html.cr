require "../syntax_highlighter"

class Crystal::SyntaxHighlighter::HTML < Crystal::SyntaxHighlighter
  def initialize(@io : IO)
  end

  def render(type, value)
    case type
    when :COMMENT
      span "c", ::HTML.escape(value)
    when :NUMBER
      span "n", value
    when :CHAR
      span "s", ::HTML.escape(value)
    when :SYMBOL
      span "n", ::HTML.escape(value)
    when :CONST
      span "t", value
    when :STRING
      span "s", ::HTML.escape(value)
    when :IDENT
      span "m", value
    when :KEYWORD, :SELF
      span "k", value
    when :PRIMITIVE_LITERAL
      span "n", value
    when :OPERATOR
      span "o", ::HTML.escape(value)
    when :DELIMITER_START, :DELIMITED_TOKEN, :DELIMITER_END,
         :STRING_ARRAY_START, :STRING_ARRAY_TOKEN, :STRING_ARRAY_END
      ::HTML.escape(value, @io)
    else
      @io << value
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
