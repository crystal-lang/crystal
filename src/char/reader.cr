struct Char
  # A `Char::Reader` allows iterating a `String` by Chars.
  #
  # As soon as you instantiate a `Char::Reader` it will decode the first
  # char in the `String`, which can be accessed by invoking `current_char`.
  # At this point `pos`, the current position in the string, will equal zero.
  # Successive calls to `next_char` return the next chars in the string,
  # advancing `pos`.
  #
  # NOTE: The null character `'\0'` will be returned in `current_char` when
  # the end is reached (as well as when the string is empty). Thus, `has_next?`
  # will return `false` only when `pos` is equal to the string's bytesize, in which
  # case `current_char` will always be `'\0'`.
  #
  # NOTE: For performance reasons, `Char::Reader` has value semantics, so care
  # must be taken when a reader is declared as a local variable and passed to
  # another method:
  #
  # ```
  # def lstrip(reader)
  #   until reader.current_char.whitespace?
  #     reader.next_char
  #   end
  #   reader
  # end
  #
  # # caller's internal state is untouched
  # reader = Char::Reader.new("   abc")
  # lstrip(reader)
  # reader.current_char # => ' '
  #
  # # to modify caller's internal state, the method must return a new reader
  # reader = lstrip(reader)
  # reader.current_char # => 'a'
  # ```
  struct Reader
    include Enumerable(Char)

    # Returns the reader's String.
    getter string : String

    # Returns the current character, or `'\0'` if the reader is at the end of
    # the string.
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.current_char # => 'a'
    # reader.next_char
    # reader.current_char # => 'b'
    # reader.next_char
    # reader.current_char # => '\0'
    # ```
    getter current_char : Char

    # Returns the size of the `#current_char` (in bytes) as if it were encoded in UTF-8.
    #
    # ```
    # reader = Char::Reader.new("aé")
    # reader.current_char_width # => 1
    # reader.next_char
    # reader.current_char_width # => 2
    # ```
    getter current_char_width : Int32

    # Returns the byte position of the current character.
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.pos # => 0
    # reader.next_char
    # reader.pos # => 1
    # ```
    getter pos : Int32

    # If there was an error decoding the current char because
    # of an invalid UTF-8 byte sequence, returns the byte
    # that produced the invalid encoding. Returns `0` if the char would've been
    # out of bounds. Otherwise returns `nil`.
    getter error : UInt8?

    # Creates a reader with the specified *string* positioned at
    # byte index *pos*.
    def initialize(@string : String, pos = 0)
      @pos = pos.to_i
      @current_char = '\0'
      @current_char_width = 0
      decode_current_char
    end

    # Creates a reader that will be positioned at the last char
    # of the given string.
    def initialize(*, at_end @string : String)
      @pos = @string.bytesize
      @current_char = '\0'
      @current_char_width = 0
      decode_previous_char
    end

    # Returns the current character.
    #
    # Returns `nil` if the reader is at the end of the string.
    def current_char? : Char?
      if has_next?
        current_char
      end
    end

    # Returns `true` if the reader is not at the end of the string.
    #
    # NOTE: This only means `#next_char` will successfully increment `#pos`; if
    # the reader is already at the last character, `#next_char` will return the
    # terminating null byte because there isn't really a next character.
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.has_next? # => true
    # reader.next_char # => 'b'
    # reader.has_next? # => true
    # reader.next_char # => '\0'
    # reader.has_next? # => false
    # ```
    def has_next? : Bool
      @pos < @string.bytesize
    end

    # Tries to read the next character in the string.
    #
    # If the reader is at the end of the string before or after incrementing
    # `#pos`, returns `nil`.
    #
    # ```
    # reader = Char::Reader.new("abc")
    # reader.next_char?   # => 'b'
    # reader.next_char?   # => 'c'
    # reader.next_char?   # => nil
    # reader.current_char # => '\0'
    # ```
    def next_char? : Char?
      next_pos = @pos + @current_char_width
      if next_pos <= @string.bytesize
        @pos = next_pos
        decode_current_char
        current_char?
      end
    end

    # Reads the next character in the string.
    #
    # If the reader is at the end of the string after incrementing `#pos`,
    # returns `'\0'`. If the reader is already at the end beforehand, raises
    # `IndexError`.
    #
    # ```
    # reader = Char::Reader.new("abc")
    # reader.next_char # => 'b'
    # reader.next_char # => 'c'
    # reader.next_char # => '\0'
    # reader.next_char # raise IndexError
    # ```
    def next_char : Char
      next_pos = @pos + @current_char_width
      if next_pos <= @string.bytesize
        @pos = next_pos
        decode_current_char
      else
        raise IndexError.new
      end
    end

    # Returns the next character in the `#string` without incrementing `#pos`.
    #
    # Returns `'\0'` if the reader is at the last character of the string.
    # Raises `IndexError` if the reader is at the end.
    #
    # ```
    # reader = Char::Reader.new("ab")
    # reader.peek_next_char # => 'b'
    # reader.current_char   # => 'a'
    # ```
    def peek_next_char : Char
      next_pos = @pos + @current_char_width

      if next_pos > @string.bytesize
        raise IndexError.new
      end

      decode_char_at(next_pos) do |code_point|
        code_point.unsafe_chr
      end
    end

    # Returns `true` if the reader is not at the beginning of the string.
    def has_previous? : Bool
      @pos > 0
    end

    # Tries to read the previous character in the string.
    #
    # Returns `nil` if the reader is already at the beginning of the string.
    # Otherwise decrements `#pos`.
    #
    # ```
    # reader = Char::Reader.new(at_end: "abc")
    # reader.previous_char? # => 'b'
    # reader.previous_char? # => 'a'
    # reader.previous_char? # => nil
    # ```
    def previous_char? : Char?
      if has_previous?
        decode_previous_char
      end
    end

    # Reads the previous character in the string.
    #
    # Raises `IndexError` if the reader is already at the beginning of the
    # string. Otherwise decrements `#pos`.
    #
    # ```
    # reader = Char::Reader.new(at_end: "abc")
    # reader.previous_char # => 'b'
    # reader.previous_char # => 'a'
    # reader.previous_char # raises IndexError
    # ```
    def previous_char : Char
      unless has_previous?
        raise IndexError.new
      end

      decode_previous_char.as(Char)
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
    def each(&) : Nil
      while has_next?
        yield current_char

        @pos += @current_char_width
        decode_current_char
      end
    end

    # :nodoc:
    # See also: `IO#read_char_with_bytesize`.
    private def decode_char_at(pos, & : UInt32, Int32, UInt8? ->)
      first = byte_at(pos)
      if first < 0x80
        return yield first, 1, nil
      end

      if first < 0xc2
        invalid_byte_sequence
      end

      second = byte_at(pos + 1)
      if (second & 0xc0) != 0x80
        invalid_byte_sequence
      end

      if first < 0xe0
        return yield (first << 6) &+ (second &- 0x3080), 2, nil
      end

      third = byte_at(pos + 2)
      if (third & 0xc0) != 0x80
        invalid_byte_sequence
      end

      if first < 0xf0
        if first == 0xe0 && second < 0xa0
          invalid_byte_sequence
        end

        if first == 0xed && second >= 0xa0
          invalid_byte_sequence
        end

        return yield (first << 12) &+ (second << 6) &+ (third &- 0xE2080), 3, nil
      end

      if first == 0xf0 && second < 0x90
        invalid_byte_sequence
      end

      if first == 0xf4 && second >= 0x90
        invalid_byte_sequence
      end

      fourth = byte_at(pos + 3)
      if (fourth & 0xc0) != 0x80
        invalid_byte_sequence
      end

      if first < 0xf5
        return yield (first << 18) &+ (second << 12) &+ (third << 6) &+ (fourth &- 0x3C82080), 4, nil
      end

      invalid_byte_sequence
    end

    private macro invalid_byte_sequence
      return yield Char::REPLACEMENT.ord.to_u32!, 1, first.to_u8!
    end

    @[AlwaysInline]
    private def decode_current_char
      decode_char_at(@pos) do |code_point, width, error|
        @current_char_width = width
        @error = error
        @current_char = code_point.unsafe_chr
      end
    end

    # The reverse UTF-8 DFA transition table for reference: (contrast with
    # `Unicode::UTF8_ENCODING_DFA`)
    #
    #              accepted (initial state)
    #              | 1 continuation byte
    #              | | 2 continuation bytes; disallow overlong encodings up to U+07FF
    #              | | | 2 continuation bytes; disallow surrogate pairs
    #              | | | | 3 continuation bytes; disallow overlong encodings up to U+FFFF
    #              | | | | | 3 continuation bytes; disallow codepoints above U+10FFFF
    #              v v v v v v
    #
    #            | 0 2 3 4 5 6
    # -----------+------------
    # 0x00..0x7F | 0 _ _ _ _ _
    # 0x80..0x8F | 2 3 5 5 _ _
    # 0x90..0x9F | 2 3 6 6 _ _
    # 0xA0..0xBF | 2 4 6 6 _ _
    # 0xC2..0xDF | _ 0 _ _ _ _
    # 0xE0..0xE0 | _ _ _ 0 _ _
    # 0xE1..0xEC | _ _ 0 0 _ _
    # 0xED..0xED | _ _ 0 _ _ _
    # 0xEE..0xEF | _ _ 0 0 _ _
    # 0xF0..0xF0 | _ _ _ _ _ 0
    # 0xF1..0xF3 | _ _ _ _ 0 0
    # 0xF4..0xF4 | _ _ _ _ 0 _
    private def decode_char_before(pos, & : UInt32, Int32, UInt8? ->)
      fourth = byte_at(pos - 1)
      if fourth <= 0x7f
        return yield fourth, 1, nil
      end

      if fourth > 0xbf || pos < 2
        invalid_byte_sequence_before
      end

      third = byte_at(pos - 2)
      if 0xc2 <= third <= 0xdf
        return yield (third << 6) &+ (fourth &- 0x3080), 2, nil
      end

      if (third & 0xc0) != 0x80 || pos < 3
        invalid_byte_sequence_before
      end

      second = byte_at(pos - 3)
      if second & 0xf0 == 0xe0
        if second == 0xe0 && third <= 0x9f
          invalid_byte_sequence_before
        end

        if second == 0xed && third >= 0xa0
          invalid_byte_sequence_before
        end

        return yield (second << 12) &+ (third << 6) &+ (fourth &- 0xE2080), 3, nil
      end

      if (second & 0xc0) != 0x80 || pos < 4
        invalid_byte_sequence_before
      end

      first = byte_at(pos - 4)
      if second <= 0x8f
        unless 0xf1 <= first <= 0xf4
          invalid_byte_sequence_before
        end
      else
        unless 0xf0 <= first <= 0xf3
          invalid_byte_sequence_before
        end
      end

      return yield (first << 18) &+ (second << 12) &+ (third << 6) &+ (fourth &- 0x3C82080), 4, nil
    end

    private macro invalid_byte_sequence_before
      return yield Char::REPLACEMENT.ord.to_u32!, 1, fourth.to_u8!
    end

    @[AlwaysInline]
    private def decode_previous_char
      return nil if @pos == 0

      decode_char_before(@pos) do |code_point, width, error|
        @current_char_width = width
        @pos -= width
        @error = error
        @current_char = code_point.unsafe_chr
      end
    end

    private def byte_at(i)
      @string.to_unsafe[i].to_u32
    end
  end
end
