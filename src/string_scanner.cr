# `StringScanner` provides for lexical scanning operations on a `String`.
#
# NOTE: To use `StringScanner`, you must explicitly import it with `require "string_scanner"`
#
# ### Example
#
# ```
# require "string_scanner"
#
# s = StringScanner.new("This is an example string")
# s.eos? # => false
#
# s.scan(/\w+/) # => "This"
# s.scan(/\w+/) # => nil
# s.scan(/\s+/) # => " "
# s.scan(/\s+/) # => nil
# s.scan(/\w+/) # => "is"
# s.eos?        # => false
#
# s.scan(/\s+/) # => " "
# s.scan(/\w+/) # => "an"
# s.scan(/\s+/) # => " "
# s.scan(/\w+/) # => "example"
# s.scan(/\s+/) # => " "
# s.scan(/\w+/) # => "string"
# s.eos?        # => true
#
# s.scan(/\s+/) # => nil
# s.scan(/\w+/) # => nil
# ```
#
# Scanning a string means remembering the position of a _scan offset_, which is
# just an index. Scanning moves the offset forward, and matches are sought
# after the offset; usually immediately after it.
#
# ### Method Categories
#
# Methods that advance the scan offset:
# * `#scan`
# * `#scan_until`
# * `#skip`
# * `#skip_until`
#
# Methods that look ahead:
# * `#peek`
# * `#check`
# * `#check_until`
#
# Methods that deal with the position of the offset:
# * `#offset`
# * `#offset=`
# * `#eos?`
# * `#reset`
# * `#terminate`
#
# Methods that deal with the last match:
# * `#[]`
# * `#[]?`
#
# Miscellaneous methods:
# * `#inspect`
# * `#string`
class StringScanner
  @last_match : Regex::MatchData | StringMatchData | Nil

  getter last_match
  getter byte_offset : Int32

  def initialize(@str : String)
    @byte_offset = 0
  end

  # Sets the *position* of the scan offset.
  def offset=(position : Int)
    raise IndexError.new unless position >= 0
    @byte_offset = @str.char_index_to_byte_index(position) || @str.bytesize
  end

  # Returns the current position of the scan offset.
  def offset : Int32
    @str.byte_index_to_char_index(@byte_offset).not_nil!
  end

  # Rewinds the scan head by `len` characters.
  def rewind(len : Int)
    return if len <= 0

    @byte_offset -= lookbehind_byte_length(len)
  end

  # Tries to match with *pattern* at the current position. If there's a match,
  # the scanner advances the scan offset, the last match is saved, and it
  # returns the matched string. Otherwise, the scanner returns `nil`. If *pattern*
  # is an Int, the scanner will be advanced by that number of characters, and the
  # scanned string returned.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("test string")
  # s.scan(/\w+/)  # => "test"
  # s.scan(/\w+/)  # => nil
  # s.scan(/\s\w/) # => " s"
  # s.scan('t')    # => "t"
  # s.scan(2)      # => "ri"
  # s.scan("ng")   # => "ng"
  # s.scan(/.*/)   # => ""
  # ```
  def scan(pattern : Regex, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : String?
    match(pattern, advance: true, options: options | Regex::MatchOptions::ANCHORED)
  end

  # :ditto:
  def scan(pattern : String) : String?
    match(pattern, advance: true, anchored: true)
  end

  # :ditto:
  def scan(pattern : Char) : String?
    match(pattern, advance: true, anchored: true)
  end

  def scan(pattern : Int) : String
    scan_len = lookahead_byte_length(pattern)
    idx = @byte_offset
    @byte_offset += scan_len
    result = @str.byte_slice(idx, scan_len)
    @last_match = StringMatchData.new(result)
    result
  end

  # Reads a single character from the string, or returns nil if at the end.
  def read_char : Char?
    char = current_char? || return nil
    @byte_offset += char.bytesize
    char
  end

  def unscan : Nil
    match = @last_match
    return if match.nil?

    @byte_offset -= match[0].bytesize
    @last_match = nil
  end

  # Scans the string _until_ the *pattern* is matched. Returns the substring up
  # to and including the end of the match, the last match is saved, and
  # advances the scan offset. Returns `nil` if no match.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("test string")
  # s.scan_until(/ s/) # => "test s"
  # s.scan_until(/ s/) # => nil
  # s.scan_until('r')  # => "tr"
  # s.scan_until("ng") # => "ing"
  # ```
  def scan_until(pattern : Regex, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : String?
    match(pattern, advance: true, options: options)
  end

  # :ditto:
  def scan_until(pattern : String) : String?
    match(pattern, advance: true, anchored: false)
  end

  # :ditto:
  def scan_until(pattern : Char) : String?
    match(pattern, advance: true, anchored: false)
  end

  private def match(pattern : Regex, advance : Bool = true, options : Regex::MatchOptions = Regex::MatchOptions::ANCHORED)
    match = pattern.match_at_byte_index(@str, @byte_offset, options)
    @last_match = match
    if match
      start = @byte_offset
      new_byte_offset = match.byte_end(0).to_i
      @byte_offset = new_byte_offset if advance

      @str.byte_slice(start, new_byte_offset - start)
    else
      nil
    end
  end

  private def match(pattern : String | Char, advance = true, anchored = true)
    @last_match = nil
    if pattern.bytesize > @str.bytesize - @byte_offset
      nil
    elsif anchored
      i = 0
      # check string starts with string or char
      unsafe_ptr = @str.to_unsafe + @byte_offset
      pattern.each_byte do |byte|
        return nil unless unsafe_ptr[i] == byte
        i += 1
      end
      # ok, it starts
      result = pattern.to_s
      @last_match = StringMatchData.new(result)
      @byte_offset += pattern.bytesize if advance
      result
    elsif (found = @str.byte_index(pattern, @byte_offset))
      finish = found + pattern.bytesize
      result = @str.byte_slice(@byte_offset, finish - @byte_offset)
      @byte_offset = finish if advance
      @last_match = StringMatchData.new(result)
      result
    end
  end

  # Attempts to skip over the given *pattern* beginning with the scan offset.
  # In other words, the pattern is not anchored to the current scan offset.
  #
  # If there's a match, the scanner advances the scan offset, the last match is
  # saved, and it returns the size of the skipped match. Otherwise it returns
  # `nil` and does not advance the offset.
  #
  # This method is the same as `#scan`, but without returning the matched
  # string.
  def skip(pattern : Regex, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : Int32?
    match = scan(pattern, options: options)
    match.size if match
  end

  # :ditto:
  def skip(pattern : String) : Int32?
    match = scan(pattern)
    match.size if match
  end

  # :ditto:
  def skip(pattern : Char) : Int32?
    match = scan(pattern)
    match.size if match
  end

  # Advances the offset by `len` chars. Prefer this to `scanner.offset += len`,
  # since that can cause a full scan of the string in the case of multibyte
  # characters.
  def skip(pattern : Int) : Int32?
    return if pattern <= 0

    @byte_offset += lookahead_byte_length(pattern)

    pattern
  end

  # Attempts to skip _until_ the given *pattern* is found after the scan
  # offset. In other words, the pattern is not anchored to the current scan
  # offset.
  #
  # If there's a match, the scanner advances the scan offset, the last match is
  # saved, and it returns the size of the skip. Otherwise it returns `nil`
  # and does not advance the
  # offset.
  #
  # This method is the same as `#scan_until`, but without returning the matched
  # string.
  def skip_until(pattern : Regex, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : Int32?
    match = scan_until(pattern, options: options)
    match.size if match
  end

  # :ditto:
  def skip_until(pattern : String) : Int32?
    match = scan_until(pattern)
    match.size if match
  end

  # :ditto:
  def skip_until(pattern : Char) : Int32?
    match = scan_until(pattern)
    match.size if match
  end

  # Returns the value that `#scan` would return, without advancing the scan
  # offset. The last match is still saved, however.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("this is a string")
  # s.offset = 5
  # s.check(/\w+/) # => "is"
  # s.check(/\w+/) # => "is"
  # ```
  def check(pattern : Regex, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : String?
    match(pattern, advance: false, options: options | Regex::MatchOptions::ANCHORED)
  end

  # :ditto:
  def check(pattern : String) : String?
    match(pattern, advance: false, anchored: true)
  end

  # :ditto:
  def check(pattern : Char) : String?
    match(pattern, advance: false, anchored: true)
  end

  # Returns the value that `#scan_until` would return, without advancing the
  # scan offset. The last match is still saved, however.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("test string")
  # s.check_until(/tr/) # => "test str"
  # s.check_until(/g/)  # => "test string"
  # ```
  def check_until(pattern : Regex, *, options : Regex::MatchOptions = Regex::MatchOptions::None) : String?
    match(pattern, advance: false, options: options)
  end

  # :ditto:
  def check_until(pattern : String) : String?
    match(pattern, advance: false, anchored: false)
  end

  # :ditto:
  def check_until(pattern : Char) : String?
    match(pattern, advance: false, anchored: false)
  end

  # Returns the *n*-th subgroup in the most recent match.
  #
  # Raises an exception if there was no last match or if there is no subgroup.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("Fri Dec 12 1975 14:39")
  # regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
  # s.scan(regex) # => "Fri Dec 12"
  # s[0]          # => "Fri Dec 12"
  # s[1]          # => "Fri"
  # s[2]          # => "Dec"
  # s[3]          # => "12"
  # s["wday"]     # => "Fri"
  # s["month"]    # => "Dec"
  # s["day"]      # => "12"
  # ```
  def [](n) : String
    @last_match.not_nil![n]
  end

  # Returns the nilable *n*-th subgroup in the most recent match.
  #
  # Returns `nil` if there was no last match or if there is no subgroup.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("Fri Dec 12 1975 14:39")
  # regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
  # s.scan(regex)  # => "Fri Dec 12"
  # s[0]?          # => "Fri Dec 12"
  # s[1]?          # => "Fri"
  # s[2]?          # => "Dec"
  # s[3]?          # => "12"
  # s[4]?          # => nil
  # s["wday"]?     # => "Fri"
  # s["month"]?    # => "Dec"
  # s["day"]?      # => "12"
  # s["year"]?     # => nil
  # s.scan(/more/) # => nil
  # s[0]?          # => nil
  # ```
  def []?(n) : String?
    @last_match.try(&.[n]?)
  end

  # Returns `true` if the scan offset is at the end of the string.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("this is a string")
  # s.eos?                # => false
  # s.scan(/(\w+\s?){4}/) # => "this is a string"
  # s.eos?                # => true
  # ```
  def eos? : Bool
    @byte_offset >= @str.bytesize
  end

  # Resets the scan offset to the beginning and clears the last match.
  def reset
    @last_match = nil
    @byte_offset = 0
  end

  # Moves the scan offset to the end of the string and clears the last match.
  def terminate
    @last_match = nil
    @byte_offset = @str.bytesize
  end

  # Returns the string being scanned.
  def string : String
    @str
  end

  # Extracts a string corresponding to string[offset,*len*], without advancing
  # the scan offset.
  def peek(len) : String
    return "" if len.zero?

    @str.byte_slice(@byte_offset, lookahead_byte_length(len))
  end

  # Extracts a string corresponding to string[offset - len, len], without advancing
  # the scan offset.
  def peek_behind(len) : String
    return "" if len.zero?
    byte_len = lookbehind_byte_length(len)
    byte_len = @byte_offset if byte_len > @byte_offset
    @str.byte_slice(@byte_offset - byte_len, byte_len)
  end

  # Returns the current byte at the scan head.
  def current_byte? : UInt8?
    @str.byte_at?(@byte_offset)
  end

  # :ditto:
  def current_byte : UInt8
    @str.byte_at(@byte_offset)
  end

  # Returns the byte before the scan head.
  def previous_byte? : UInt8?
    @str.byte_at?(@byte_offset - 1)
  end

  # :ditto:
  def previous_byte : UInt8
    @str.byte_at(@byte_offset - 1)
  end

  # Decodes a single character at the scan head.
  def current_char? : Char?
    char_reader.current_char?
  end

  # :ditto:
  def current_char : Char
    char_reader.current_char
  end

  # Decodes one character before the scan head
  def previous_char? : Char?
    char_reader.previous_char?
  end

  # :ditto:
  def previous_char : Char
    char_reader.previous_char
  end

  @[AlwaysInline]
  private def char_reader : Char::Reader
    Char::Reader.new(@str, @byte_offset)
  end

  # Returns the remainder of the string after the scan offset.
  #
  # ```
  # require "string_scanner"
  #
  # s = StringScanner.new("this is a string")
  # s.scan(/(\w+\s?){2}/) # => "this is "
  # s.rest                # => "a string"
  # ```
  def rest : String
    @str.byte_slice(@byte_offset, @str.bytesize - @byte_offset)
  end

  # Writes a representation of the scanner.
  #
  # Includes the current position of the offset, the total size of the string,
  # and five characters near the current position.
  def inspect(io : IO) : Nil
    offset = offset()
    io << "#<StringScanner "
    io << offset << '/' << @str.size << ' '

    if offset.zero?
      io << '|'
      peek(5).inspect(io)
    elsif eos?
      peek_behind(5).inspect(io)
      io << '|'
    else
      peek_behind(2).inspect(io)
      io << '|'
      peek(3).inspect(io)
    end

    io << '>'
  end

  private def lookahead_byte_length(len : Int) : Int
    return len if @str.single_byte_optimizable?
    return 0 if len.zero?

    # some redundant logic here from String#find_start_and_end, but in this case
    # it is likely we are far into the string and len is small, so it is very
    # important not to start at the beginning of the string.
    reader = self.char_reader
    i = 0

    reader.each do
      break if i == len
      i += 1
    end

    reader.pos - @byte_offset
  end

  private def lookbehind_byte_length(len : Int) : Int
    return len if @str.single_byte_optimizable?
    return 0 if len.zero?

    reader = self.char_reader

    until len.zero?
      reader.previous_char
      len -= 1
    end

    @byte_offset - reader.pos
  end

  # Returns true if the stream is at the beginning of a line and not at EOS.
  def beginning_of_line? : Bool
    return false if eos?
    return true if @byte_offset.zero?

    previous_char == '\n'
  end

  # Returns true if the last #scan resulted in a match
  def matched? : Bool
    !@last_match.nil?
  end

  # :nodoc:
  struct StringMatchData
    def initialize(@str : String)
    end

    def []?(n : Int) : String?
      return unless n == 0 || n == -1
      @str
    end

    def [](n : Int) : String
      self[n]? || raise IndexError.new("Invalid capture group index: #{n}")
    end

    def []?(group_name : String) : String?
      nil
    end

    def [](group_name : String) : String
      raise KeyError.new("Capture group '#{group_name}' does not exist")
    end

    def []?(range : Range) : Array(String)?
      start, count = Indexable.range_to_index_and_count(range, 1) || return nil
      _, count = Indexable.normalize_start_and_count(start, count, 1) { return nil }
      return [] of String if count == 0
      [@str]
    end

    def [](range : Range) : Array(String)
      self[range]? || raise IndexError.new
    end
  end
end
