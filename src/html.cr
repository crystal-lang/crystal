module HTML
  SUBSTITUTIONS = {
    '!'      => "&#33;",
    '"'      => "&quot;",
    '$'      => "&#36;",
    '%'      => "&#37;",
    '&'      => "&amp;",
    '\''     => "&#39;",
    '('      => "&#40;",
    ')'      => "&#41;",
    '='      => "&#61;",
    '>'      => "&gt;",
    '<'      => "&lt;",
    '+'      => "&#43;",
    '@'      => "&#64;",
    '['      => "&#91;",
    ']'      => "&#93;",
    '`'      => "&#96;",
    '{'      => "&#123;",
    '}'      => "&#125;",
    '\u{a0}' => "&nbsp;",
  }

  def self.escape(string : String) : String
    string.gsub(SUBSTITUTIONS)
  end

  def self.escape(string : String, io : IO)
    string.each_char do |char|
      io << SUBSTITUTIONS.fetch(char, char)
    end
  end

  def self.unescape(string : String)
    return string unless string.includes? '&'

    string.gsub(/&(apos|amp|quot|gt|lt|nbsp|\#[0-9]+|\#[xX][0-9A-Fa-f]+);/) do |string, _match|
      match = _match[1]
      case match
      when "apos" then "'"
      when "amp"  then "&"
      when "quot" then "\""
      when "gt"   then ">"
      when "lt"   then "<"
      when "nbsp" then " "
      when /\A#0*(\d+)\z/
        n = $1.to_i
        if n <= Char::MAX_CODEPOINT
          n.unsafe_chr
        else
          "&##{$1};"
        end
      when /\A#x([0-9a-f]+)\z/i
        n = $1.to_i(16)
        if n <= Char::MAX_CODEPOINT
          n.unsafe_chr
        else
          "&#x#{$1};"
        end
      else
        "&#{match};"
      end
    end
  end
end
