# `StringScanner` provides for lexical scanning operations on a `String`.
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
  @last_match : Regex::MatchData?

  def initialize(@str : String)
    @byte_offset = 0
  end

  # Sets the *position* of the scan offset.
  def offset=(position : Int)
    raise IndexError.new unless position >= 0
    @byte_offset = @str.char_index_to_byte_index(position) || @str.bytesize
  end

  # Returns the current position of the scan offset.
  def offset
    @str.byte_index_to_char_index(@byte_offset).not_nil!
  end

  # Tries to match with *pattern* at the current position. If there's a match,
  # the scanner advances the scan offset, the last match is saved, and it
  # returns the matched string. Otherwise, the scanner returns `nil`.
  #
  # ```
  # s = StringScanner.new("test string")
  # s.scan(/\w+/)   # => "test"
  # s.scan(/\w+/)   # => nil
  # s.scan(/\s\w+/) # => " string"
  # s.scan(/.*/)    # => nil
  # ```
  def scan(pattern)
    match(pattern, advance: true, options: Regex::Options::ANCHORED)
  end

  # Scans the string _until_ the *pattern* is matched. Returns the substring up
  # to and including the end of the match, the last match is saved, and
  # advances the scan offset. Returns `nil` if no match.
  #
  # ```
  # s = StringScanner.new("test string")
  # s.scan_until(/tr/) # => "test str"
  # s.scan_until(/tr/) # => nil
  # s.scan_until(/g/)  # => "ing"
  # ```
  def scan_until(pattern)
    match(pattern, advance: true, options: Regex::Options::None)
  end

  private def match(pattern, advance = true, options = Regex::Options::ANCHORED)
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

  # Attempts to skip over the given *pattern* beginning with the scan offset.
  # In other words, the pattern is not anchored to the current scan offset.
  #
  # If there's a match, the scanner advances the scan offset, the last match is
  # saved, and it returns the size of the skipped match. Otherwise it returns
  # `nil` and does not advance the offset.
  #
  # This method is the same as `#scan`, but without returning the matched
  # string.
  def skip(pattern)
    match = scan(pattern)
    match.size if match
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
  def skip_until(pattern)
    match = scan_until(pattern)
    match.size if match
  end

  # Returns the value that `#scan` would return, without advancing the scan
  # offset. The last match is still saved, however.
  #
  # ```
  # s = StringScanner.new("this is a string")
  # s.offset = 5
  # s.check(/\w+/) # => "is"
  # s.check(/\w+/) # => "is"
  # ```
  def check(pattern)
    match(pattern, advance: false, options: Regex::Options::ANCHORED)
  end

  # Returns the value that `#scan_until` would return, without advancing the
  # scan offset. The last match is still saved, however.
  #
  # ```
  # s = StringScanner.new("test string")
  # s.check_until(/tr/) # => "test str"
  # s.check_until(/g/)  # => "test string"
  # ```
  def check_until(pattern)
    match(pattern, advance: false, options: Regex::Options::None)
  end

  # Returns the *n*-th subgroup in the most recent match.
  #
  # Raises an exception if there was no last match or if there is no subgroup.
  #
  # ```
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
  def [](n)
    @last_match.not_nil![n]
  end

  # Returns the nilable *n*-th subgroup in the most recent match.
  #
  # Returns `nil` if there was no last match or if there is no subgroup.
  #
  # ```
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
  def []?(n)
    @last_match.try(&.[n]?)
  end

  # Returns `true` if the scan offset is at the end of the string.
  #
  # ```
  # s = StringScanner.new("this is a string")
  # s.eos?                # => false
  # s.scan(/(\w+\s?){4}/) # => "this is a string"
  # s.eos?                # => true
  # ```
  def eos?
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
  def string
    @str
  end

  # Extracts a string corresponding to string[offset,*len*], without advancing
  # the scan offset.
  def peek(len)
    @str[offset, len]
  end

  # Returns the remainder of the string after the scan offset.
  #
  # ```
  # s = StringScanner.new("this is a string")
  # s.scan(/(\w+\s?){2}/) # => "this is "
  # s.rest                # => "a string"
  # ```
  def rest
    @str.byte_slice(@byte_offset, @str.bytesize - @byte_offset)
  end

  # Writes a representation of the scanner.
  #
  # Includes the current position of the offset, the total size of the string,
  # and five characters near the current position.
  def inspect(io : IO)
    io << "#<StringScanner "
    offset = offset()
    io << offset << "/" << @str.size
    start = Math.min(Math.max(offset - 2, 0), Math.max(0, @str.size - 5))
    io << " \"" << @str[start, 5] << "\" >"
  end
end
