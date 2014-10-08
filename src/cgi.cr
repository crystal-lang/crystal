module CGI
  # URL-decode a string.
  #
  #     CGI.unescape("%27Stop%21%27+said+Fred") => "'Stop!' said Fred"
  def self.unescape(string : String)
    String.build { |io| unescape(string, io) }
  end

  # URL-decode a string and write the result to an IO.
  def self.unescape(string : String, io : IO)
    i = 0
    bytesize = string.bytesize
    while i < bytesize
      byte = string.unsafe_byte_at(i)
      char = byte.chr
      i = unescape_one string, bytesize, i, byte, char, io
    end
    io
  end

  # URL-encode a string.
  #
  #     CGI.escape("'Stop!' said Fred") => "%27Stop%21%27+said+Fred"
  def self.escape(string : String)
    String.build { |io| escape(string, io) }
  end

  # URL-encode a string and write the result to an IO.
  def self.escape(string : String, io : IO)
    string.each_char do |char|
      if char.alphanumeric? || char == '_' || char == '.' || char == '-'
        io.write_byte char.ord.to_u8
      else
        char.each_byte do |byte|
          io.write_byte '%'.ord.to_u8
          io.write_byte '0'.ord.to_u8 if byte < 16
          byte.to_s(16, io)
        end
      end
    end
    io
  end

  # Parses an HTTP query string into a Hash(String, Array(String))
  #
  #     CGI.parse("foo=bar&foo=baz&qux=zoo") #=> {"foo" => ["bar", "baz"], "qux" => ["zoo"]}
  def self.parse(query : String)
    parsed = {} of String => Array(String)
    parse(query) do |key, value|
      ary = parsed[key] ||= [] of String
      ary.push value
    end
    parsed
  end

  # Parses an HTTP query and yields each key-value pair
  #
  #     CGI.parse(query) do |key, value|
  #       # ...
  #     end
  def self.parse(query : String)
    key = nil
    buffer = StringIO.new

    i = 0
    bytesize = query.bytesize
    while i < bytesize
      byte = query.unsafe_byte_at(i)
      char = byte.chr

      case char
      when '='
        key = buffer.to_s
        buffer.clear
        i += 1
      when '&', ';'
        value = buffer.to_s
        buffer.clear
        yield key.not_nil!, value
        i += 1
      else
        i = unescape_one query, bytesize, i, byte, char, buffer
      end
    end

    if key
      yield key.not_nil!, buffer.to_s
    else
      yield buffer.to_s, ""
    end
  end

  def self.build_form
    form_builder = FormBuilder.new
    yield form_builder
    form_builder.to_s
  end

  struct FormBuilder
    def initialize
      @string = StringIO.new
    end

    def add(key, value)
      @string << '&' unless @string.empty?
      CGI.escape key, @string
      @string << '='
      CGI.escape value, @string if value
      self
    end

    def to_s
      @string.to_s
    end
  end

  private def self.unescape_one(string, bytesize, i, byte, char, io)
    if char == '+'
      io.write_byte ' '.ord.to_u8
      i += 1
      return i
    end

    if char == '%' && i < bytesize - 2
      i += 1
      first = string.unsafe_byte_at(i)
      first_num = first.chr.to_i 16, or_else: nil
      unless first_num
        io.write_byte byte
        return i
      end

      i += 1
      second = string.unsafe_byte_at(i)
      second_num = second.chr.to_i 16, or_else: nil
      unless second_num
        io.write_byte byte
        io.write_byte first
        return i
      end

      io.write_byte (first_num * 16 + second_num).to_u8
      i += 1
      return i
    end

    io.write_byte byte
    i += 1
    i
  end
end
