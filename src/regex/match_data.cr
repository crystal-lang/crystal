class MatchData
  getter regex
  getter length
  getter string

  def initialize(@regex, @code, @string, @pos, @ovector, @length)
  end

  def begin(n)
    check_index_out_of_bounds n

    @ovector[n * 2]
  end

  def end(n)
    check_index_out_of_bounds n

    @ovector[n * 2 + 1]
  end

  def [](n)
    check_index_out_of_bounds n

    start = @ovector[n * 2]
    finish = @ovector[n * 2 + 1]
    @string.byte_slice(start, finish - start)
  end

  def [](group_name : String)
    ret = PCRE.get_named_substring(@code, @string, @ovector, @length + 1, group_name, out value)
    raise ArgumentError.new("Match group named '#{group_name}' does not exist") if ret < 0
    String.new(value)
  end

  def to_s(io : IO)
    io << "MatchData("
    @string.inspect(io)
    if length > 0
      io << " ["
      length.times do |i|
        io << ", " if i > 0
        self[i + 1].inspect(io)
      end
      io << "]"
    end
    io << ")"
  end

  private def check_index_out_of_bounds(index)
    raise IndexOutOfBounds.new if index > @length
  end
end
