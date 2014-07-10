struct Symbol
  def inspect(io : IO)
    io << ":"
    to_s io
  end

  def to_s(io : IO)
    io << to_s
  end
end
