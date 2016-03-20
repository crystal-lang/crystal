struct Char
  # Returns the codepoint of this char.
  #
  # The codepoint is the integer
  # representation. The Universal Coded Character Set (UCS) standard,
  # commonly known as Unicode, assigns names and meanings to numbers, these
  # numbers are called codepoints.
  #
  # For values below and including 127 this matches the ASCII codes
  # and thus its byte representation.
  #
  # ```
  # 'a'.ord      # => 97
  # '\0'.ord     # => 0
  # '\u007f'.ord # => 127
  # '☃'.ord      # => 9731
  # ```
  def ord : Int32
    1
  end
end
