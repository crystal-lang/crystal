struct OAuth::Signature
  def initialize(@consumer_key, @client_shared_secret, @oauth_token = nil, @token_shared_secret = nil, @extra_params = nil)
  end

  def base_string(request, ssl, ts, nonce)
    base_string request, ssl, gather_params(request, ts, nonce)
  end

  def key
    String.build do |str|
      CGI.escape @client_shared_secret, str
      str << '&'
      if token_shared_secret = @token_shared_secret
        CGI.escape token_shared_secret, str
      end
    end
  end

  def compute(request, ssl, ts, nonce)
    base_string = base_string(request, ssl, ts, nonce)
    Base64.strict_encode64(OpenSSL::HMAC.digest :sha1, key, base_string)
  end

  def authorization_header(request, ssl, ts, nonce)
    oauth_signature = compute request, ssl, ts, nonce

    auth_header = AuthorizationHeader.new
    auth_header.add "oauth_consumer_key", @consumer_key
    auth_header.add "oauth_signature_method", "HMAC-SHA1"
    auth_header.add "oauth_timestamp", ts
    auth_header.add "oauth_nonce", nonce
    auth_header.add "oauth_signature", oauth_signature
    auth_header.add "oauth_token", @oauth_token
    auth_header.add "oauth_version", "1.0"
    @extra_params.try &.each do |key, value|
      auth_header.add key, value
    end
    auth_header.to_s
  end

  private def base_string(request, ssl, params)
    host, port = host_and_port(request, ssl)

    String.build do |str|
      str << request.method
      str << '&'
      str << (ssl ? "https" : "http")
      str << "%3A%2F%2F"
      CGI.escape host, str
      if port
        str << ':'
        str << port
      end
      CGI.escape (request.uri.path || "/"), str
      str << '&'
      str << params
    end
  end

  private def gather_params(request, ts, nonce)
    params = Params.new
    params.add "oauth_consumer_key", @consumer_key
    params.add "oauth_nonce", nonce
    params.add "oauth_signature_method", "HMAC-SHA1"
    params.add "oauth_timestamp", ts
    params.add "oauth_token", @oauth_token
    params.add "oauth_version", "1.0"

    @extra_params.try &.each do |key, value|
      params.add key, value
    end

    if query = request.uri.query
      params.add_query query
    end

    body = request.body
    content_type = request.headers["Content-type"]?
    if body && content_type == "application/x-www-form-urlencoded"
      params.add_query body
    end

    params
  end

  private def host_and_port(request, ssl)
    host_header = request.headers["Host"]
    if colon_index = host_header.index ':'
      host = host_header[0 ... colon_index]
      port = host_header[colon_index + 1 .. -1].to_i
      {host, port}
    else
      {host_header, nil}
    end
  end
end
