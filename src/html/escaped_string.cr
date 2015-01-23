class HTML::EscapedString
  SUBSTITUTIONS = {
    '&'  => "&amp;"
    '\"' => "&quot;",
    '\'' => "&apos;",
    '<'  => "&lt;",
    '>'  => "&gt;",
  }

  def self.escape(str)
    new(str).to_s
  end

  def initialize(@str)
    @escaped_str = StringIO.new
  end

  def to_s
    escaped.to_s
  end

  private def escaped
    @str.each_char do |char|
      @escaped_str << SUBSTITUTIONS.fetch(char, char)
    end
    @escaped_str
  end
end

class String
  def html_escape
    HTML::EscapedString.escape(self)
  end
end
