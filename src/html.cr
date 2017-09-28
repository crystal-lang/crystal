require "./html/entities"

# Provides HTML escaping and unescaping methods.
module HTML
  private SUBSTITUTIONS = {
    '&'  => "&amp;",
    '<'  => "&lt;",
    '>'  => "&gt;",
    '"'  => "&quot;",
    '\'' => "&#39;",
  }

  # Escapes special characters in HTML, namely
  # `&`, `<`, `>`, `"` and `'`.
  #
  # ```
  # require "html"
  #
  # HTML.escape("Crystal & You") # => "Crystal &amp; You"
  # ```
  def self.escape(string : String) : String
    string.gsub(SUBSTITUTIONS)
  end

  # Same as `escape(string)` but ouputs the result to
  # the given *io*.
  #
  # ```
  # io = IO::Memory.new
  # HTML.escape("Crystal & You", io) # => nil
  # io.to_s                          # => "Crystal &amp; You"
  # ```
  def self.escape(string : String, io : IO) : Nil
    string.each_char do |char|
      io << SUBSTITUTIONS.fetch(char, char)
    end
  end

  # Returns a string where named and numeric character references
  # (e.g. &gt;, &#62;, &x3e;) in *string* are replaced with the corresponding
  # unicode characters.
  #
  # ```
  # HTML.unescape("Crystal &amp; You") # => "Crystal & You"
  # ```
  def self.unescape(string : String) : String
    string.gsub(/&(?:([a-zA-Z]{2,32};?)|\#([0-9]+);?|\#[xX]([0-9A-Fa-f]+);?)/) do |string, match|
      if code = match[1]?
        # Try to find the code
        value = named_entity(code)
        if value
          value
        elsif !code.ends_with?(';')
          # If we can't find it and it doesn't end with ';',
          # we need to find each prefix of it.
          # We start from the largest prefix.
          removed = 0
          until code.empty?
            code = code.rchop
            removed += 1

            value = named_entity(code)
            if value
              # If we find it, we need to append the part that
              # isn't part of the matched code
              value += string[-removed..-1]
              break
            end
          end

          # We either found the code or not,
          # in which case we need to return the original string
          value || string
        end
      elsif code = match[2]?
        # Find by decimal code
        n = code.to_i
        n <= Char::MAX_CODEPOINT ? n.unsafe_chr : string
      elsif code = match[3]?
        # Find by hexadecimal code
        n = code.to_i(16)
        n <= Char::MAX_CODEPOINT ? n.unsafe_chr : string
      else
        string
      end
    end
  end

  private def self.named_entity(code)
    HTML::SINGLE_CHAR_ENTITIES[code]? || HTML::DOUBLE_CHAR_ENTITIES[code]?
  end
end
