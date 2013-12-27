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

  def self.parse(string)
    string =~ Regexp.new("(?<scheme>.*):\\/\\/(?<host>[\\w\\.]*)(:(?<port>\\d*))?(?<path>\\/[^?]*)?(\\?(?<qs>.*))?")
    scheme = $1
    host = $2
    port = $4.empty? ? port_from_scheme($1) : $4.to_i
    path = $5.empty? ? nil : $5
    query_string = $7.empty? ? nil : $7

    URI.new scheme, host, port, path, query_string
  end

  def self.port_from_scheme(scheme)
    case scheme
    when "http" then 80
    when "https" then 443
    else raise "Unknown URI scheme: #{scheme}"
    end
  end
end
