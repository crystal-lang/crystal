class MatchData
  getter regex
  getter length
  getter string

  def initialize(@regex, @code, @string, @pos, @ovector, @length)
  end

  def begin(n)
    byte_index_to_char_index byte_begin(n)
  end

  def end(n)
    byte_index_to_char_index byte_end(n)
  end

  def byte_begin(n)
    check_index_out_of_bounds n
    @ovector[n * 2]
  end

  def byte_end(n)
    check_index_out_of_bounds n
    @ovector[n * 2 + 1]
  end

  def []?(n)
    return unless valid_group?(n)

    start = @ovector[n * 2]
    finish = @ovector[n * 2 + 1]
    return if start < 0
    @string.byte_slice(start, finish - start)
  end

  def [](n)
    check_index_out_of_bounds n

    self[n]?.not_nil!
  end

  def []?(group_name : String)
    ret = LibPCRE.get_stringnumber(@code, group_name)
    return if ret < 0
    self[ret]?
  end

  def [](group_name : String)
    match = self[group_name]?
    unless match
      raise ArgumentError.new("Match group named '#{group_name}' does not exist")
    end
    match
  end

  # Returns the part of the original string before the matching part.
  # If the matching part of the string starts at the start of the
  # string, then the empty string is returned.
  #
  # ```
  # "Crystal".match(/yst/) { |md| md.pre_match } #=> "Cr"
  # ```
  def pre_match
    if self.begin(0) == 0
      ""
    else
      @string[0..self.begin(0) - 1]
    end
  end

  # Returns the part of the original string after the matching part.
  # If the matching part of the string ends at the end of the
  # string, then the empty string is returned.
  #
  # ```
  # "Crystal".match(/yst/) { |md| md.post_match } #=> "al"
  # ```
  def post_match
    @string[self.end(0)..-1]
  end

  def inspect(io : IO)
    to_s(io)
  end

  def to_s(io : IO)
    name_table = @regex.name_table

    io << "#<MatchData "
    self[0].inspect(io)
    if length > 0
      io << " "
      length.times do |i|
        io << " " if i > 0
        io << name_table.fetch(i + 1) { i + 1 }
        io << ":"
        self[i + 1]?.inspect(io)
      end
    end
    io << ">"
  end

  private def byte_index_to_char_index(index)
    reader = CharReader.new(@string)
    i = 0
    reader.each do |char|
      break if reader.pos == index
      i += 1
    end
    i
  end

  private def check_index_out_of_bounds(index)
    raise IndexError.new unless valid_group?(index)
  end

  private def valid_group?(index)
    index <= @length
  end
end
