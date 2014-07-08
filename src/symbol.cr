struct Symbol
  def inspect(io)
    io << ":"
    to_s io
  end

  def to_s(io)
    io << to_s
  end
end
