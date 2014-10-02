class URI
  property scheme
  property host
  property port
  property path
  property query_string

  def initialize(@scheme, @host, @port, @path, @query_string)
  end

  def full_path
    String.build do |str|
      str << (@path || "/")
      str << "?" << @query_string if @query_string
    end
  end

  def self.parse(string : String)
    case string
    when /\A(?<scheme>.*):\/\/(?<host>[^:\/\?]*)(:(?<port>\d*))?(?<path>\/[^?]*)?(\?(?<qs>.*))?\Z/
      scheme = $1
      host = $2
      port = $4.empty? ? nil : $4.to_i
      path = $5.empty? ? nil : $5
      query_string = $7.empty? ? nil : $7
    else
      if question_index = string.index '?'
        path = string[0 ... question_index]
        query_string = string[question_index + 1 .. -1]
      else
        path = string
      end
    end

    URI.new scheme, host, port, path, query_string
  end
end
