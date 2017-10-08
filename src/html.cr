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

  # These replacements permit compatibility with old numeric entities that
  # assumed Windows-1252 encoding.
  # http://www.whatwg.org/specs/web-apps/current-work/multipage/tokenization.html#consume-a-character-reference
  private CHARACTER_REPLACEMENTS = {
    '\u20AC', # First entry is what 0x80 should be replaced with.
    '\u0081',
    '\u201A',
    '\u0192',
    '\u201E',
    '\u2026',
    '\u2020',
    '\u2021',
    '\u02C6',
    '\u2030',
    '\u0160',
    '\u2039',
    '\u0152',
    '\u008D',
    '\u017D',
    '\u008F',
    '\u0090',
    '\u2018',
    '\u2019',
    '\u201C',
    '\u201D',
    '\u2022',
    '\u2013',
    '\u2014',
    '\u02DC',
    '\u2122',
    '\u0161',
    '\u203A',
    '\u0153',
    '\u009D',
    '\u017E',
    '\u0178', # Last entry is 0x9F.
    # 0x00->'\uFFFD' is handled programmatically.
    # 0x0D->'\u000D' is a no-op.
  }

  # Returns a string where named and numeric character references
  # (e.g. &gt;, &#62;, &x3e;) in *string* are replaced with the corresponding
  # unicode characters. This method decodes all HTML5 entities including those
  # without a trailing semicolon (such as `&copy`).
  #
  # ```
  # HTML.unescape("Crystal &amp; You") # => "Crystal & You"
  # ```
  def self.unescape(string : String) : String
    string.gsub(/&(?:([a-zA-Z0-9]{2,32};?)|\#([0-9]+);?|\#[xX]([0-9A-Fa-f]+);?)/) do |string, match|
      if code = match[1]?
        # Try to find the code
        value = named_entity(code)

        unless value || code.ends_with?(';')
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
        end

        # We either found the code or not,
        # in which case we need to return the original string
        value || string
      elsif code = match[2]?
        # Find by decimal code
        decode_codepoint(code.to_i) || string
      elsif code = match[3]?
        # Find by hexadecimal code
        decode_codepoint(code.to_i(16)) || string
      else
        string
      end
    end
  end

  private def self.named_entity(code)
    HTML::SINGLE_CHAR_ENTITIES[code]? || HTML::DOUBLE_CHAR_ENTITIES[code]?
  end

  # see https://html.spec.whatwg.org/multipage/parsing.html#numeric-character-reference-end-state
  private def self.decode_codepoint(codepoint)
    case codepoint
    when 0x80..0x9F
      # Replace characters from Windows-1252 with UTF-8 equivalents.
      CHARACTER_REPLACEMENTS[codepoint - 0x80].to_s
    when 0,
         .>(Char::MAX_CODEPOINT),
         0xD800..0xDFFF # unicode surrogate characters
      # Replace invalid characters with replacement character.
      '\uFFFD'
    else
      # don't replace disallowed codepoints
      unless codepoint == 0x007F ||
             # unicode noncharacters
             (0xFDD0..0xFDEF).includes?(codepoint) ||
             # last two of each plane (nonchars) disallowed
             codepoint & 0xFFFF >= 0xFFFE ||
             # unicode control characters expect space
             (codepoint < 0x0020 && !{0x0009, 0x000A, 0x000C}.includes?(codepoint))
        codepoint.unsafe_chr
      end
    end
  end
end
