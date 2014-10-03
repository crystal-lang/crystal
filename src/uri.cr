class URI
  property scheme
  property host
  property port
  property path
  property query

  def initialize(@scheme = nil, @host = nil, @port = nil, @path = nil, @query = nil)
  end

  def full_path
    String.build do |str|
      str << (@path || "/")
      str << "?" << @query if @query
    end
  end

  def to_s(io : IO)
    if scheme = @scheme
      io << scheme
      io << "://"
    end
    if host = @host
      io << host
    end
    if (port = @port) && !((scheme == "http" && port == 80) || (scheme == "https" && port == 443))
      io << ':'
      io << port
    end
    if path
      io << path
    end
    if query
      io << '?'
      io << query
    end
  end

  def self.parse(string : String)
    case string
    when /\A(?<scheme>.*):\/\/(?<host>[^:\/\?]*)(:(?<port>\d*))?(?<path>\/[^?]*)?(\?(?<qs>.*))?\Z/
      scheme = $1
      host = $2
      port = $4.empty? ? nil : $4.to_i
      path = $5.empty? ? nil : $5
      query = $7.empty? ? nil : $7
    else
      if question_index = string.index '?'
        path = string[0 ... question_index]
        query = string[question_index + 1 .. -1]
      else
        path = string
      end
    end

    URI.new scheme, host, port, path, query
  end
end
