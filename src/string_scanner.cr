# `StringScanner` provides for lexical scanning operations on a String.
#
# ### Example
#
#     require "string_scanner"
#     s = StringScanner.new("This is an example string")
#     s.eos?         # => false
#
#     s.scan(/\w+/)  # => "This"
#     s.scan(/\w+/)  # => nil
#     s.scan(/\s+/)  # => " "
#     s.scan(/\s+/)  # => nil
#     s.scan(/\w+/)  # => "is"
#     s.eos?         # => false
#
#     s.scan(/\s+/)  # => " "
#     s.scan(/\w+/)  # => "an"
#     s.scan(/\s+/)  # => " "
#     s.scan(/\w+/)  # => "example"
#     s.scan(/\s+/)  # => " "
#     s.scan(/\w+/)  # => "string"
#     s.eos?         # => true
#
#     s.scan(/\s+/)  # => nil
#     s.scan(/\w+/)  # => nil
#
# Scanning a string means remembering the position of a _scan offset_, which is
# just an index. Scanning moves the offset forward, and matches are sought
# after the offset; usually immediately after it.
class StringScanner
  def initialize(@str)
    @offset = 0
    @length = @str.length
  end

  # Returns the current position of the scan offset.
  getter offset

  # Sets the position of the scan offset.
  def offset=(position : Int)
    raise IndexError.new unless position >= 0
    @offset = position
  end

  # Tries to match with pattern at the current position. If there's a match,
  # the scanner advances the scan offset and returns the matched string.
  # Otherwise, the scanner returns nil.
  #
  #     s = StringScanner.new("test string")
  #     s.scan(/\w+/)   # => "test"
  #     s.scan(/\w+/)   # => nil
  #     s.scan(/\s\w+/) # => " string"
  #     s.scan(/.*/)    # => nil
  def scan(re)
    match = re.match(@str, @offset, Regex::Options::ANCHORED)
    @last_match = match
    if match
      @offset = match.end(0).to_i
      match[0]
    else
      nil
    end
  end

  # Returns the `n`-th subgroup in the most recent match.
  #
  # Raises an exception if there was no last match or if there is no subgroup.
  #
  #     s = StringScanner.new("Fri Dec 12 1975 14:39")
  #     regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
  #     s.scan(regex)  # => "Fri Dec 12"
  #     s[0]           # => "Fri Dec 12"
  #     s[1]           # => "Fri"
  #     s[2]           # => "Dec"
  #     s[3]           # => "12"
  #     s["wday"]      # => "Fri"
  #     s["month"]     # => "Dec"
  #     s["day"]       # => "12"
  def [](n)
    @last_match.not_nil![n]
  end

  # Returns the nilable `n`-th subgroup in the most recent match.
  #
  # Returns `nil` if there was no last match or if there is no subgroup.
  #
  #     s = StringScanner.new("Fri Dec 12 1975 14:39")
  #     regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
  #     s.scan(regex)  # => "Fri Dec 12"
  #     s[0]?           # => "Fri Dec 12"
  #     s[1]?           # => "Fri"
  #     s[2]?           # => "Dec"
  #     s[3]?           # => "12"
  #     s[4]?           # => nil
  #     s["wday"]?      # => "Fri"
  #     s["month"]?     # => "Dec"
  #     s["day"]?       # => "12"
  #     s["year"]?      # => nil
  #     s.scan(/more/)  # => nil
  #     s[0]?           # => nil
  def []?(n)
    @last_match.try(&.[n]?)
  end


  # Returns true if the scan offset is at the end of the string.
  #
  #     s = StringScanner.new("this is a string")
  #     s.eos?                 # => false
  #     s.scan(/(\w+\s?){4}/)  # => "this is a string"
  #     s.eos?                 # => true
  def eos?
    @offset >= @length
  end

  # Returns the string being scanned.
  def string
    @str
  end

  # Extracts a string corresponding to string[offset,`len`], without advancing
  # the scan offset.
  def peek(len)
    @str[@offset, len]
  end

  # Returns the remainder of the string after the scan offset.
  #
  #     s = StringScanner.new("this is a string")
  #     s.scan(/(\w+\s?){2}/)  # => "this is "
  #     s.rest                 # => "a string"
  def rest
    @str[@offset, @length - @offset]
  end

  # Writes a representation of the scanner.
  #
  # Includes the current position of the offset, the total size of the string,
  # and five characters near the current position.
  def inspect(io : IO)
    io << "#<StringScanner "
    io << @offset.to_s << "/" << @length.to_s
    start = Math.min( Math.max(@offset-2, 0), @length-5)
    io << " \"" << @str[start, 5] << "\" >"
  end
end
