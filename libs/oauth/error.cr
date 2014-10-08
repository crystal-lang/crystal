class OAuth::Error < ::Exception
  def initialize(@response)
    super()
  end

  def to_s(io : IO)
    io << "OAuth::Error with response:\n"
    @response.to_io(io)
    io.puts
  end
end
