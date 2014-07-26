class HTTP::Client
  def self.exec(host, port, request)
    TCPSocket.open(host, port) do |socket|
      request.to_io(socket)
      HTTP::Response.from_io(socket)
    end
  end

  def self.exec_ssl(host, port, request)
    TCPSocket.open(host, port) do |socket|
      SSLSocket.open(socket) do |ssl_socket|
        request.to_io(ssl_socket)
        HTTP::Response.from_io(ssl_socket)
      end
    end
  end

  def self.get(host, port, path, headers = nil)
    exec(host, port, HTTP::Request.new("GET", path, headers))
  end

  def self.get(url)
    exec_url(url) do |path, headers|
      HTTP::Request.new("GET", path, headers)
    end
  end

  def self.get_json(url)
    Json.parse(get(url).body.not_nil!)
  end

  def self.post(url, body)
    exec_url(url) do |path, headers|
      HTTP::Request.new("POST", path, headers, body)
    end
  end

  # private

  def self.exec_url(url)
    uri = URI.parse(url)
    host_header = uri.port ? "#{uri.host}:#{uri.port}" : uri.host
    request = yield uri.full_path, {"Host" => host_header}

    case uri.scheme
    when "http" then exec(uri.host, uri.port || 80, request)
    when "https" then exec_ssl(uri.host, uri.port || 443, request)
    else raise "Unsuported scheme: #{uri.scheme}"
    end
  end
end
