require "colorize"
require "../syntax_highlighter"

# A syntax highlighter that renders Crystal source code with ANSI escape codes
# suitable for terminal highlighting.
#
# ```
# code = %(foo = bar("baz\#{PI + 1}") # comment)
# colorized = Crystal::SyntaxHighlighter::Colorize.highlight(code)
# colorized # => "foo \e[91m=\e[0m bar(\e[93m\"baz\#{\e[0;36mPI\e[0;93m \e[0;91m+\e[0;93m \e[0;35m1\e[0;93m}\"\e[0m) \e[90m# comment\e[0m"
# ```
class Crystal::SyntaxHighlighter::Colorize < Crystal::SyntaxHighlighter
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
    code
  end

  # Creates a new instance of a Colorize syntax highlighter.
  #
  # Appends highlighted output (when calling `#highlight`) to *io*.
  def initialize(@io : IO, @colorize : ::Colorize::Object(String) = ::Colorize.with.toggle(true))
  end

  property colors : Hash(TokenType, ::Colorize::Color) = {
    :comment           => :dark_gray,
    :number            => :magenta,
    :char              => :light_yellow,
    :symbol            => :magenta,
    :string            => :light_yellow,
    :interpolation     => :light_yellow,
    :const             => :cyan,
    :operator          => :light_red,
    :ident             => :light_green,
    :keyword           => :light_red,
    :primitive_literal => :magenta,
    :self              => :blue,
  } of TokenType => ::Colorize::Color

  def render(type : TokenType, value : String)
    colorize(type, value)
  end

  def render_delimiter(&)
    @colorize.fore(colors[TokenType::STRING]).surround(@io) do
      yield
    end
  end

  def render_interpolation(&)
    colorize :INTERPOLATION, "\#{"
    @colorize.fore(:default).surround(@io) do
      yield
    end
    colorize :INTERPOLATION, "}"
  end

  def render_string_array(&)
    @colorize.fore(colors[TokenType::STRING]).surround(@io) do
      yield
    end
  end

  private def colorize(type : TokenType, token)
    if color = colors[type]?
      @colorize.fore(color).surround(@io) do
        @io << token
      end
    else
      @io << token
    end
  end
end
