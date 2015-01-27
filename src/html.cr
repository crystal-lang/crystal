module HTML
  SUBSTITUTIONS = {
    '&'  => "&amp;"
    '\"' => "&quot;",
    '\'' => "&apos;",
    '<'  => "&lt;",
    '>'  => "&gt;",
  }

  def self.escape(string: String)
    String.build { |io| escape(string, io) }
  end

  def self.escape(string: String, io: IO)
    string.each_char do |char|
      io << SUBSTITUTIONS.fetch(char, char)
    end
  end
end
