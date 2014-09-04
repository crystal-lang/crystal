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
    string =~ /\A(?<scheme>.*):\/\/(?<host>[^:\/\?]*)(:(?<port>\d*))?(?<path>\/[^?]*)?(\?(?<qs>.*))?\Z/
    md = MatchData.last
    scheme = md[1]
    host = md[2]
    port = md[4].empty? ? nil : md[4].to_i
    path = md[5].empty? ? nil : md[5]
    query_string = md[7].empty? ? nil : md[7]

    URI.new scheme, host, port, path, query_string
  end
end
