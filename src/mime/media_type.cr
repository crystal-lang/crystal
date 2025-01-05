require "uri"
require "http"
require "mime"

module MIME
  # A `MediaType` describes a MIME content type with optional parameters.
  struct MediaType
    getter media_type : String

    # Creates a new `MediaType` instance.
    def initialize(@media_type, @params = {} of String => String)
      @params.each_key do |name|
        raise Error.new("Invalid parameter name #{name.inspect}") unless MIME::MediaType.token? name
      end
    end

    def to_s(io : IO) : Nil
      io << media_type

      @params.each do |key, value|
        io << "; "
        io << key.downcase << '='

        if MIME::MediaType.token? value
          io << value
        else
          io << '"'
          MIME::MediaType.quote_string(value, io)
          io << '"'
        end
      end
    end

    # Returns the value for the parameter given by *key*. If not found, raises `KeyError`.
    #
    # ```
    # require "mime/media_type"
    #
    # MIME::MediaType.parse("text/plain; charset=UTF-8")["charset"] # => "UTF-8"
    # MIME::MediaType.parse("text/plain; charset=UTF-8")["foo"]     # raises KeyError
    # ```
    def [](key : String) : String
      @params[key]
    end

    # Returns the value for the parameter given by *key*. If not found, returns `nil`.
    #
    # ```
    # require "mime/media_type"
    #
    # MIME::MediaType.parse("text/plain; charset=UTF-8")["charset"]? # => "UTF-8"
    # MIME::MediaType.parse("text/plain; charset=UTF-8")["foo"]?     # => nil
    # ```
    def []?(key : String) : String?
      @params[key]?
    end

    # Sets the value of parameter *key* to the given value.
    #
    # ```
    # require "mime/media_type"
    #
    # mime_type = MIME::MediaType.parse("x-application/example")
    # mime_type["foo"] = "bar"
    # mime_type["foo"] # => "bar"
    # ```
    def []=(key : String, value : String)
      raise Error.new("Invalid parameter name") unless MIME::MediaType.token? key
      @params[key] = value
    end

    # Returns the value for the parameter given by *key*, or when not found the value given by *default*.
    #
    # ```
    # require "mime/media_type"
    #
    # MIME::MediaType.parse("x-application/example").fetch("foo", "baz")          # => "baz"
    # MIME::MediaType.parse("x-application/example; foo=bar").fetch("foo", "baz") # => "bar"
    # ```
    def fetch(key : String, default : T) : String | T forall T
      @params.fetch(key, default)
    end

    # Returns the value for the parameter given by *key*, or when not found calls the given block with the *key*.
    #
    # ```
    # require "mime/media_type"
    #
    # MIME::MediaType.parse("x-application/example").fetch("foo") { |key| key }          # => "foo"
    # MIME::MediaType.parse("x-application/example; foo=bar").fetch("foo") { |key| key } # => "bar"
    # ```
    def fetch(key : String, &block : String -> _)
      @params.fetch(key) { |key| yield key }
    end

    # Calls the given block for each parameter and passes in the key and the value.
    def each_parameter(&block : String, String -> _) : Nil
      @params.each do |key, value|
        yield key, value
      end
    end

    # Returns an iterator over the parameter which behaves like an `Iterator` returning a `Tuple` of key and value.
    def each_parameter : Iterator(Tuple(String, String))
      @params.each
    end

    # First component of `media_type`.
    #
    # ```
    # require "mime/media_type"
    #
    # MIME::MediaType.new("text/plain").type # => "text"
    # MIME::MediaType.new("foo").type        # => "foo"
    # ```
    #
    def type : String
      index = media_type.byte_index('/'.ord) || media_type.bytesize
      media_type.byte_slice(0, index)
    end

    # Second component of `media_type` or `nil`.
    #
    # ```
    # require "mime/media_type"
    #
    # MIME::MediaType.new("text/plain").sub_type # => "plain"
    # MIME::MediaType.new("foo").sub_type        # => nil
    # ```
    def sub_type : String?
      index = media_type.byte_index('/'.ord) || return
      media_type.byte_slice(index + 1, media_type.bytesize - index - 1)
    end

    # Parses a MIME type string representation including any optional parameters,
    # per RFC 1521.
    # Media types are the values in `Content-Type` and `Content-Disposition` HTTP
    # headers (RFC 2183).
    #
    # Media type is lowercased and trimmed of whitespace. Param keys are lowercased.
    #
    # Raises `MIME::Error` on error.
    def self.parse(string : String) : MediaType
      parse_impl(string) { |err| raise MIME::Error.new("Parsing error: #{err} (#{string.dump})") }
    end

    # Parses a MIME type string representation including any optional parameters,
    # per RFC 1521.
    # Media types are the values in `Content-Type` and `Content-Disposition` HTTP
    # headers (RFC 2183).
    #
    # Media type is lowercased and trimmed of whitespace. Param keys are lowercased.
    #
    # Returns `nil` on error.
    def self.parse?(string : String) : MediaType?
      parse_impl(string) { return nil }
    end

    # This methods parses a MIME media type according to RFC 2231
    private def self.parse_impl(string : String, &block : String -> NoReturn)
      reader = Char::Reader.new(string)

      # 1. Reading the type and subtype, separated by a '/'
      #    media_type := type "/" sub_type

      sub_type_start = -1 # invalid value to detect if sub type start was read
      while reader.has_next?
        char = reader.current_char

        if char == ';'
          # when ';' is reached, the media type is finished
          # optional parameters may follow
          break
        elsif char == '/'
          # Abort if there had already been a '/'
          yield "Invalid '/' at #{reader.pos}" if sub_type_start > -1

          # The separator between type and subtype has been reached
          sub_type_start = reader.pos
          reader.next_char
        elsif token?(char)
          reader.next_char
        else
          yield "Invalid character '#{char}' at #{reader.pos}"
        end
      end

      # string is empty or first character was a ';'
      yield "Missing media type" if reader.pos == 0

      mediatype = string.byte_slice(0, reader.pos).strip.downcase

      # string contained only whitespace as media type
      yield "Missing media type" if mediatype.empty?

      # 2. Consume parameters, consisting of attribute-value pairs
      #     parameters := *( ";" parameter)
      #     parameter  := attribute "=" value

      # Stores regular attribute-value pairs
      params = {} of String => String

      # Stores extended parameters with continuation values
      continuation = Hash(String, Hash(String, String)).new do |hash, key|
        hash[key] = {} of String => String
      end

      while reader.has_next?
        # Consume optional whitespace
        reader = consume_whitespace(reader)

        break unless reader.has_next?

        # ';' has not been consumed previously
        reader.next_char

        # Consume optional whitespace
        reader = consume_whitespace(reader)

        break unless reader.has_next?

        key_start = reader.pos

        # Consume attribute name and break at '='
        while reader.has_next?
          case char = reader.current_char
          when ';'
            yield "Invalid ';' at #{reader.pos}, expecting '='"
          when '='
            break
          else
            unless token?(char)
              yield "Invalid character '#{char}' at #{reader.pos}"
            end

            reader.next_char
          end
        end

        # Read the attribute name into a variable. It is case-insensitive and
        # might be surrounded by whitespace, hence `.rstrip.downcase`.
        key = string.byte_slice(key_start, reader.pos - key_start).rstrip.downcase

        yield "Missing attribute name at #{key_start}" if key.empty?

        # Consume '='
        if reader.has_next?
          reader.next_char
        else
          yield "Missing attribute value at #{reader.pos}"
        end

        # '*' designates an extended parameter name
        # It is not yet processed but extended parameters are added to a
        # special `continuation` map instead of `params` for later processing.
        base_key, star, section = key.partition('*')
        if star.empty?
          if params.has_key?(key)
            yield "Duplicate key '#{key}' at #{key_start}"
          end

          # Consume parameter value
          reader, value = parse_parameter_value(reader) { |err| yield err }

          # Add the attribute-value pair to `params`.
          params[key] = value
        else
          # Remove whitespace surrounding '*'
          base_key = base_key.rstrip
          section = section.lstrip

          section.each_char_with_index do |char, index|
            unless char.ascii_number? || (char == '*' && index == section.bytesize - 1)
              yield "Invalid key '#{key}' at #{key_start}"
            end
          end

          # TODO: Using a different data structure than `Hash` for storing
          # continuation sections could improve performance.
          normalized_key = "#{base_key}*#{section}"
          continuation_map = continuation[base_key]
          if continuation_map.has_key?(normalized_key)
            yield "Duplicate key '#{key}' at #{key_start}"
          end

          # Consume parameter value
          reader, value = parse_parameter_value(reader) { |err| yield err }

          # Add the attribute-value pair to `continuation` map.
          continuation_map[normalized_key] = value
        end
      end

      # 3. Resolve continuation parameters
      #
      #     extended-parameter := (extended-initial-name "=" extended-value) /
      #                           (extended-other-names "=" extended-other-values)
      #
      #     initial-section := "*0"
      #
      #     other-sections := "*" ("1" / "2" / "3" / "4" / "5" /
      #                            "6" / "7" / "8" / "9") *DIGIT)
      #
      #     extended-initial-name := attribute [initial-section] "*"
      #
      #     extended-other-names := attribute other-sections "*"
      #
      #     extended-initial-value := [charset] "'" [language] "'" extended-other-values
      #
      #     extended-other-values := *(ext-octet / attribute-char)
      continuation.each do |base_key, pieces|
        # `#{base_key}*` is an extended-initial-name without initial-section.
        # This is not the start of a continuation, just a single encoded value.
        if value = pieces["#{base_key}*"]?
          if decoded = decode_rfc2231(value)
            params[base_key] = decoded
          end
          next
        end

        # All other pieces are extended-parameter and need to be sequentially
        # ordered by section number
        valid = false
        composite_value = String.build do |io|
          counter = 0
          loop do
            part_key = "#{base_key}*#{counter}"
            if part = pieces[part_key]?
              valid = true
              io << part
            elsif part = pieces["#{part_key}*"]?
              valid = true

              io << decode_rfc2231(part) || next
            else
              break
            end
            counter += 1
          end
        end
        if valid
          params[base_key] = composite_value
        else
          # TODO: Not sure if invalid parameter should error or just be ignored.
          # yield "Invalid extended parameter: '#{base_key}'"
        end
      end

      # text types should automatically use UTF-8 charset unless specified differently.
      if mediatype.starts_with?("text/")
        params["charset"] ||= "utf-8"
      end

      MediaType.new mediatype, params
    end

    private def self.parse_parameter_value(reader, &)
      reader = consume_whitespace(reader)

      # Quoted value.
      if reader.current_char == '"'
        reader.next_char

        quoted = true
        waiting_for_closing_quote = true
      else
        quoted = false
        waiting_for_closing_quote = false
      end

      value = String.build do |io|
        # Set positions for copying data from reader string to `io` in bulk.
        value_start = reader.pos
        value_end = reader.pos

        while reader.has_next?
          case char = reader.current_char
          when ';'
            break unless quoted

            reader.next_char
          when '"'
            yield "Unexpected '\"' at #{reader.pos}" unless waiting_for_closing_quote

            waiting_for_closing_quote = false
            break
          when '\\'
            reader.next_char

            char = reader.current_char
            # Escape `\\` and `\"`
            if char == '\\' || (quoted && char == '"')
              # Write everything before the escaping backslash to io, then set
              # `value_start` to the position of the escaped character, thus it
              # will be included in the next write.
              # This essentially skips writing the escaping backslash.
              io.write reader.string.to_slice[value_start, reader.pos - value_start - 1]
              value_start = reader.pos

              reader.next_char
            end
          when '='
            if quoted
              reader.next_char
            else
              yield "Unexpected '=' at #{reader.pos}"
            end
          else
            reader.next_char
          end
        end

        if quoted
          if waiting_for_closing_quote
            yield "Unclosed quote at #{reader.pos}"
          end

          # Set position for final bulk copy.
          value_end = reader.pos

          reader.next_char

          reader = consume_whitespace(reader)

          if reader.has_next? && reader.current_char != ';'
            yield "Invalid character '#{reader.current_char}' at #{reader.pos}, expecting ';'"
          end
        else
          # remove right-hand-side whitespace when unquoted

          # 1. Step one character back to check for whitespace.
          reader.previous_char if reader.has_previous?
          # 2. Remove whitespace.
          while reader.has_previous? && reader.current_char.ascii_whitespace?
            reader.previous_char
          end
          # 3. Step one character ahead again.
          reader.next_char

          value_end = reader.pos
        end

        io.write reader.string.to_slice[value_start, value_end - value_start]
      end

      return reader, value
    end

    private def self.decode_rfc2231(encoded : String)
      encoding, _, rest = encoded.partition('\'')
      _lang, _, value = rest.partition('\'')

      return if encoding.empty? || value.empty?

      encoding = encoding.downcase

      IO::Memory.new.tap do |io|
        io.set_encoding encoding

        reader = Char::Reader.new(value)
        while reader.has_next?
          case char = reader.current_char
          when '%'
            first = reader.next_char.to_i?(16) || return
            second = reader.next_char.to_i?(16) || return

            num = first << 4 | second
            io.write_byte num.to_u8
            reader.next_char
          else
            io << char
            reader.next_char
          end
        end
      end.rewind.gets_to_end
    end

    private def self.consume_whitespace(reader)
      while reader.current_char.ascii_whitespace?
        reader.next_char
      end
      reader
    end

    # :nodoc:
    def self.token?(char : Char) : Bool
      !TSPECIAL_CHARACTERS.includes?(char) && 0x20 <= char.ord < 0x7F
    end

    # :nodoc:
    def self.token?(string) : Bool
      string.each_char.all? { |char| token? char }
    end

    # :nodoc:
    def self.quote_string(string, io) : Nil
      string.each_char do |char|
        case char
        when '"', '\\'
          io << '\\'
        when '\u{00}'..'\u{1F}', '\u{7F}'
          raise ArgumentError.new("String contained invalid character #{char.inspect}")
        else
          # leave the byte as is
        end
        io << char
      end
    end
  end
end
