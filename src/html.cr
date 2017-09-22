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

  # Returns a string where some named and all numeric character references
  # (e.g. &gt;, &#62;, &x3e;) in *string* are replaced with the corresponding
  # unicode characters. Only these named entities are replaced:
  # apos, amp, quot, gt, lt and nbsp.
  #
  # ```
  # HTML.unescape("Crystal &amp; You") # => "Crystal & You"
  # ```
  def self.unescape(string : String) : String
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
