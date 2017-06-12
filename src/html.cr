# Handles encoding and decoding of HTML entities.
module HTML
  # `HTML.escape` escaping mode.
  enum EscapeMode
    # Escapes '&', '<' and '>' chars.
    CGI,
    # Escapes '&', '"', '\'', '<' and '>' chars.
    Default,
    # Escapes a XSS chars according to OWASP recommendation, rule 1.
    OWASP,
  end

  ESCAPE_SUBST = {
    # Like PHP htmlspecialchars (with ENT_NOQUOTES), Python cgi.escape, W3C recommendation.
    EscapeMode::CGI => {
      '&' => "&amp;",
      '<' => "&lt;",
      '>' => "&gt;",
    },
    # Like Python html.escape, Phoenix Phoenix.HTML, Go html.EscapeString, Django, Jinja, W3C recommendation.
    EscapeMode::Default => {
      '&' => "&amp;",
      '"' => "&quot;",
      '\'' => "&#27;",
      '<' => "&lt;",
      '>' => "&gt;",
    },
    # Like Ruby CGI.escape, PHP htmlspecialchars (with ENT_QUOTES), Rack::Utils.escape_html, OWASP recommendation.
    #
    # https://www.owasp.org/index.php/XSS_(Cross_Site_Scripting)_Prevention_Cheat_Sheet#RULE_.231_-_HTML_Escape_Before_Inserting_Untrusted_Data_into_HTML_Element_Content
    EscapeMode::OWASP => {
      '&'  => "&amp;",
      '"'  => "&quot;",
      '<'  => "&lt;",
      '>'  => "&gt;",
      '\'' => "&#27;",
      '/'  => "&#2F;",
    },
  }

  # Encodes a string with HTML entity substitutions.
  #
  # ```
  # require "html"
  #
  # HTML.escape("Crystal & You") # => "Crystal &amp; You"
  # ```
  def self.escape(string : String, mode : EscapeMode = EscapeMode::Default) : String
    string.gsub(ESCAPE_SUBST[mode])
  end

  # Encodes a string to HTML, but writes to the `IO` instance provided.
  #
  # ```
  # io = IO::Memory.new
  # HTML.escape("Crystal & You", io) # => nil
  # io.to_s                          # => "Crystal &amp; You"
  # ```
  def self.escape(string : String, io : IO, mode : EscapeMode = EscapeMode::Default)
    subst = ESCAPE_SUBST[mode]
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
