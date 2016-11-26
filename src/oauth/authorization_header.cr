# :nodoc:
struct OAuth::AuthorizationHeader
  def initialize
    @str = IO::Memory.new
    @str << "OAuth "
    @first = true
  end

  def add(key, value)
    return unless value

    @str << ", " unless @first
    @str << key
    @str << %(=")
    URI.escape value, @str
    @str << '"'
    @first = false
  end

  def to_s(io : IO)
    @str.to_s(io)
  end

  def to_s
    @str.to_s
  end
end
