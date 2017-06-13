# Handles encoding and decoding of HTML entities.
module HTML
  # `HTML.escape` escaping mode.
  ESCAPE_SUBST = {
    # Escapes '&', '<' and '>' chars.
    #
    # Like PHP htmlspecialchars (with ENT_NOQUOTES), Python cgi.escape, W3C recommendation.
    false => {
      '&' => "&amp;",
      '<' => "&lt;",
      '>' => "&gt;",
    },
    # Like Ruby CGI.escape, PHP htmlspecialchars (with ENT_QUOTES), Rack::Utils.escape_html.
    true => {
      '&'  => "&amp;",
      '"'  => "&quot;",
      '<'  => "&lt;",
      '>'  => "&gt;",
      '\'' => "&#27;",
    },
  }

  # Encodes a string with HTML entity substitutions.
  #
  # ```
  # require "html"
  #
  # HTML.escape("Crystal & You") # => "Crystal &amp; You"
  # ```
  def self.escape(string : String, escape_quotes : Bool = true) : String
    string.gsub(ESCAPE_SUBST[escape_quotes])
  end

  # Encodes a string to HTML, but writes to the `IO` instance provided.
  #
  # ```
  # io = IO::Memory.new
  # HTML.escape("Crystal & You", io) # => nil
  # io.to_s                          # => "Crystal &amp; You"
  # ```
  def self.escape(string : String, io : IO, escape_quotes : Bool = true)
    subst = ESCAPE_SUBST[escape_quotes]
    string.each_char do |char|
      io << subst.fetch(char, char)
    end
  end

  # Decodes a string that contains HTML entities.
  #
  # ```
  # HTML.unescape("Crystal &amp; You") # => "Crystal & You"
  # ```
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
