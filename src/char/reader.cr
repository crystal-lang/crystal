struct Char
  # A Char::Reader allows iterating a String by Chars.
  #
  # As soon as you instantiate a Char::Reader it will decode the first
  # char in the String, which can be accessed by invoking `current_char`.
  # At this point `pos`, the current position in the string, will equal zero.
  # Successive calls to `next_char` return the next chars in the string,
  # advancing `pos`.
  #
  # Note that the null character '\0' will be returned in `current_char` when
  # the end is reached (as well as when the string is empty). Thus, `has_next?`
  # will return `false` only when `pos` is equal to the string's bytesize, in which
  # case `current_char` will always be '\0'.
  struct Reader
    include Enumerable(Char)

    # Returns the reader's String.
    getter string : String

    # Returns the current character.
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.current_char # => 'a'
    # reader.next_char
    # reader.current_char # => 'b'
    # ```
    getter current_char : Char

    # Returns the size of the current_char (in bytes) as if it were encoded in UTF-8.
    #
    # ```
    # reader = Char::Reader.new("aé")
    # reader.current_char_width # => 1
    # reader.next_char
    # reader.current_char_width # => 2
    # ```
    getter current_char_width : Int32

    # Returns the position of the current character.
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.pos # => 0
    # reader.next_char
    # reader.pos # => 1
    # ```
    getter pos : Int32

    # Creates a reader with the specified *string*
    def initialize(@string : String)
      @pos = 0
      @current_char = '\0'
      @current_char_width = 0
      @end = false
      decode_current_char
    end

    # Returns true if there is a character left to read.
    # The terminating byte '\0' is considered a valid character
    # by this method.
    #
    # ```
    # reader = Char::Reader.new("a")
    # reader.has_next?      # => true
    # reader.peek_next_char # => '\0'
    # ```
    def has_next?
      !@end
    end

    # Reads the next character in the string,
    # `#pos` is incremented. Raises `IndexError` if the reader is
    # at the end of the `#string`
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.next_char # => 'b'
    # ```
    def next_char
      @pos += @current_char_width
      if @pos > @string.bytesize
        raise IndexError.new
      end

      decode_current_char
    end

    # Returns the next character in the `#string`
    # without incrementing `#pos`.
    # Raises `IndexError` if the reader is at
    # the end of the `#string`
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.peek_next_char # => 'b'
    # reader.current_char   # => 'a'
    # ```
    def peek_next_char
      next_pos = @pos + @current_char_width

      if next_pos > @string.bytesize
        raise IndexError.new
      end

      decode_char_at(next_pos) do |code_point, width|
        code_point.unsafe_chr
      end
    end

    # Sets `#pos` to *pos*.
    #
    # ```
    # reader = Char::Reader.new("abc")
    # reader.next_char
    # reader.next_char
    # reader.pos = 0
    # reader.current_char # => 'a'
    # ```
    def pos=(pos)
      if pos > @string.bytesize
        raise IndexError.new
      end

      @pos = pos
      decode_current_char
      pos
    end

    # Yields successive characters from `#string` starting from `#pos`.
    #
    # ```
    # reader = Char::Reader.new("abc")
    # reader.next_char
    # reader.each do |c|
    #   puts c.upcase
    # end
    # ```
    #
    # ``` text
    # B
    # C
    # ```
    def each
      while has_next?
        yield current_char
        @pos += @current_char_width
        decode_current_char
      end
      self
    end

    private def decode_char_at(pos)
      # See http://en.wikipedia.org/wiki/UTF-8#Sample_code

      first = byte_at(pos)
      if first < 0x80
        return yield first, 1
      end

      if first < 0xc2
        invalid_byte_sequence(first, pos)
      end

      second = byte_at(pos + 1)
      if (second & 0xc0) != 0x80
        invalid_byte_sequence(second, pos + 1)
      end

      if first < 0xe0
        return yield (first << 6) + (second - 0x3080), 2
      end

      third = byte_at(pos + 2)
      if (third & 0xc0) != 0x80
        invalid_byte_sequence(third, pos + 2)
      end

      if first < 0xf0
        if first == 0xe0 && second < 0xa0
          invalid_byte_sequence(second, pos + 1)
        end

        return yield (first << 12) + (second << 6) + (third - 0xE2080), 3
      end

      if first == 0xf0 && second < 0x90
        invalid_byte_sequence(second, pos + 1)
      end

      if first == 0xf4 && second >= 0x90
        invalid_byte_sequence(second, pos + 1)
      end

      fourth = byte_at(pos + 3)
      if (fourth & 0xc0) != 0x80
        invalid_byte_sequence(fourth, pos + 3)
      end

      if first < 0xf5
        return yield (first << 18) + (second << 12) + (third << 6) + (fourth - 0x3C82080), 4
      end

      invalid_byte_sequence(first, pos)
    end

    private def invalid_byte_sequence(byte, byte_position)
      raise InvalidByteSequenceError.new("Unexpected byte 0x#{byte.to_s(16)} at position #{byte_position}, malformed UTF-8")
    end

    @[AlwaysInline]
    private def decode_current_char
      decode_char_at(@pos) do |code_point, width|
        @current_char_width = width
        @end = @pos == @string.bytesize
        @current_char = code_point.unsafe_chr
      end
    end

    private def byte_at(i)
      @string.unsafe_byte_at(i).to_u32
    end
  end
end
