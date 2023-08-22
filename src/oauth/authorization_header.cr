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
    URI.encode_www_form key, @str
    @str << %(=")
    URI.encode_www_form value, @str
    @str << '"'
    @first = false
  end

  def to_s(io : IO) : Nil
    @str.to_s(io)
  end

  def to_s : String
    @str.to_s
  end
end
