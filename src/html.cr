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
    # Escapes '&', '<' and '>', '"' and '\'' chars.
    #
    # Like Ruby CGI.escape, PHP htmlspecialchars (with ENT_QUOTES), Rack::Utils.escape_html.
    true => {
      '&'  => "&amp;",
      '"'  => "&quot;",
      '<'  => "&lt;",
      '>'  => "&gt;",
      '\'' => "&#27;",
    },
  }
  ESCAPE_JAVASCRIPT_SUBST = {
    '\''     => "\\'",
    '"'      => "\\\"",
    '\\'     => "\\\\",
    '\u2028' => "&#x2028;",
    '\u2029' => "&#x2029;",
    '\n'     => "\\n",
    '\r'     => "\\n",
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
  def self.escape(string : String, io : IO, escape_quotes : Bool = true) : Nil
    subst = ESCAPE_SUBST[escape_quotes]
    string.each_char do |char|
      io << subst.fetch(char, char)
    end
  end

  # Encodes a string with JavaScript escaping substitutions.
  #
  # ```
  # require "html"
  #
  # HTML.escape_javascript("</crystal> \u2028") # => "<\\/crystal> &#x2028;"
  # ```
  def self.escape_javascript(string : String) : String
    string.gsub("\r\n", "\n").gsub(ESCAPE_JAVASCRIPT_SUBST).gsub("</", "<\\/")
  end

  # Encodes a string with JavaScript escaping, but writes to the `IO` instance provided.
  #
  # ```
  # io = IO::Memory.new
  # HTML.escape_javascript("</crystal> \u2028", io) # => nil
  # io.to_s                                         # => "<\\/crystal> &#x2028;"
  # ```
  def self.escape_javascript(string : String, io : IO) : Nil
    previous_char = '\0'
    string.each_char do |char|
      if previous_char == '\r' && char == '\n'
        previous_char = '\n'
        next
      end
      if previous_char == '<' && char == '/'
        previous_char = '/'
        io << '\\' << '/'
        next
      end
      io << ESCAPE_JAVASCRIPT_SUBST.fetch(char, char)
      previous_char = char
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
