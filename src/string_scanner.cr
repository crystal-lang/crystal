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
    if match
      @offset = match.end(0).to_i
      match[0]
    else
      nil
    end
  end

  # Returns true if the scan offset is at the end of the string.
  #
  #     s = StringScanner.new("this is a string")
  #     s.eos?                 # => false
  #     s.scan(/(\w+\s?){4}/)  # => "this is a string"
  #     s.eos?                 # => true
  def eos?
    @offset >= @str.length
  end

  # Returns the remainder of the string after the scan offset.
  #
  #     s = StringScanner.new("this is a string")
  #     s.scan(/(\w+\s?){2}/)  # => "this is "
  #     s.rest                 # => "a string"
  def rest
    @str[@offset, @str.length - @offset]
  end
end
