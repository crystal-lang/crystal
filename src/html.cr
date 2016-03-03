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

  def self.escape(string : String)
    string.gsub(SUBSTITUTIONS)
  end

  def self.escape(string : String, io : IO)
    string.each_char do |char|
      io << SUBSTITUTIONS.fetch(char, char)
    end
  end
end
