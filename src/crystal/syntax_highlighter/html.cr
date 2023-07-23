require "../syntax_highlighter"
require "html"

# A syntax highlighter that renders Crystal source code with HTML markup.
#
# ```
# code = %(foo = bar("baz\#{PI + 1}") # comment)
# html = Crystal::SyntaxHighlighter::HTML.highlight(code)
# html # => "foo <span class=\"o\">=</span> bar(<span class=\"s\">&quot;baz</span><span class=\"i\">\#{</span><span class=\"t\">PI</span> <span class=\"o\">+</span> <span class=\"n\">1</span><span class=\"i\">}</span><span class=\"s\">&quot;</span>) <span class=\"c\"># comment</span>"
# ```
class Crystal::SyntaxHighlighter::HTML < Crystal::SyntaxHighlighter
  # Highlights *code* and writes the result to *io*.
  def self.highlight(io : IO, code : String)
    new(io).highlight(code)
  end

  # Highlights *code* and returns the result.
  def self.highlight(code : String)
    String.build do |io|
      highlight(io, code)
    end
  end

  # Highlights *code* or returns unhighlighted *code* on error.
  #
  # Same as `.highlight(code : String)` except that any error is rescued and
  # returns unhighlighted source code.
  def self.highlight!(code : String)
    highlight(code)
  rescue
    ::HTML.escape(code)
  end

  # Creates a new instance of an HTML syntax highlighter.
  #
  # Appends highlighted output (when calling `#highlight`) to *io*.
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
      span "m" { ::HTML.escape(value, @io) }
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
