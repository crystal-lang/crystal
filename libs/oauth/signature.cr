struct OAuth::Signature
  def initialize(@consumer_key, @consumer_secret, @oauth_token = nil, @oauth_token_secret = nil)
  end

  def base_string(request, ssl, ts, nonce, oauth_callback = nil)
    base_string request, ssl, gather_params(request, ts, nonce, oauth_callback)
  end

  def key
    String.build do |str|
      CGI.escape @consumer_secret, str
      str << '&'
      if oauth_token_secret = @oauth_token_secret
        CGI.escape oauth_token_secret, str
      end
    end
  end

  def compute(request, ssl, ts, nonce, oauth_callback = nil)
    base_string = base_string(request, ssl, ts, nonce, oauth_callback)
    Base64.strict_encode64(OpenSSL::HMAC.digest :sha1, key, base_string)
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

  private def gather_params(request, ts, nonce, oauth_callback)
    params = Params.new
    params.add "oauth_callback", oauth_callback
    params.add "oauth_consumer_key", @consumer_key
    params.add "oauth_nonce", nonce
    params.add "oauth_signature_method", "HMAC-SHA1"
    params.add "oauth_timestamp", ts
    params.add "oauth_token", @oauth_token
    params.add "oauth_version", "1.0"

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
