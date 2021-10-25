require "colorize"
require "../syntax_highlighter"

class Crystal::SyntaxHighlighter
  class Colorize < Crystal::SyntaxHighlighter
    def initialize(@io : IO)
    end

    property colors : Hash(TokenType, ::Colorize::Color) = {
      TokenType::COMMENT           => ::Colorize::ColorANSI::DarkGray,
      TokenType::NUMBER            => ::Colorize::ColorANSI::Magenta,
      TokenType::CHAR              => ::Colorize::ColorANSI::LightYellow,
      TokenType::SYMBOL            => ::Colorize::ColorANSI::Magenta,
      TokenType::STRING            => ::Colorize::ColorANSI::LightYellow,
      TokenType::INTERPOLATION     => ::Colorize::ColorANSI::LightYellow,
      TokenType::CONST             => ::Colorize::ColorANSI::Cyan,
      TokenType::OPERATOR          => ::Colorize::ColorANSI::LightRed,
      TokenType::IDENT             => ::Colorize::ColorANSI::LightGreen,
      TokenType::KEYWORD           => ::Colorize::ColorANSI::LightRed,
      TokenType::PRIMITIVE_LITERAL => ::Colorize::ColorANSI::Magenta,
      TokenType::SELF              => ::Colorize::ColorANSI::Blue,
    } of TokenType => ::Colorize::Color

    def render(type : TokenType, value : String)
      colorize(type, value)
    end

    def render_delimiter(&)
      ::Colorize.with.fore(colors[TokenType::STRING]).surround(@io) do
        yield
      end
    end

    def render_interpolation(&)
      colorize :INTERPOLATION, "\#{"
      yield
      colorize :INTERPOLATION, "}"
    end

    def render_string_array(&)
      ::Colorize.with.fore(colors[TokenType::STRING]).surround(@io) do
        yield
      end
    end

    private def colorize(type : TokenType, token)
      if color = colors[type]?
        @io << token.colorize(color)
      else
        @io << token
      end
    end
  end
end
