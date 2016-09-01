module HTML
  ESCAPE_SUBSTITUTIONS = {
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

  UNESCAPE_SUBSTITUTIONS = ESCAPE_SUBSTITUTIONS.invert

  def self.escape(string : String) : String
    string.gsub(ESCAPE_SUBSTITUTIONS)
  end

  def self.escape(string : String, io : IO)
    string.each_char do |char|
      io << ESCAPE_SUBSTITUTIONS.fetch(char, char)
    end
  end

  def self.unescape(string : String) : String
    string.gsub(UNESCAPE_SUBSTITUTIONS)
  end
end
