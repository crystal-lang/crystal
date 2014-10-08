class OAuth::Consumer
  def initialize(@host, @consumer_key, @consumer_secret,
    @port = 443,
    scheme = "https",
    @request_token_uri = "/oauth/request_token",
    @authorize_uri = "/oauth/authorize",
    @access_token_uri = "/oauth/access_token")
    @ssl = scheme == "https"
  end

  def get_request_token(oauth_callback = "oob")
    client = HTTP::Client.new @host, @port, ssl: @ssl
    authenticate client, oauth_callback
    response = client.post @request_token_uri
    RequestToken.from_response(response.body)
  end

  private def authenticate(client, oauth_callback)
    client.before_request do |request|
      authenticate client, request, oauth_callback
      nil
    end
  end

  private def authenticate(client, request, oauth_callback)
    request.headers["Authorization"] = oauth_header(request, oauth_callback)
  end

  private def oauth_header(request, oauth_callback)
    ts = Time.now.to_i.to_s
    nonce = SecureRandom.hex

    signature = Signature.new @consumer_key, @consumer_secret, @oauth_token, @oauth_token_secret
    oauth_signature = signature.compute request, @ssl, ts, nonce, oauth_callback

    auth_header = AuthorizationHeader.new
    auth_header.add "oauth_consumer_key", @consumer_key
    auth_header.add "oauth_signature_method", "HMAC-SHA1"
    auth_header.add "oauth_timestamp", ts
    auth_header.add "oauth_nonce", nonce
    auth_header.add "oauth_callback", oauth_callback
    auth_header.add "oauth_signature", oauth_signature
    auth_header.add "oauth_token", @token
    auth_header.add "oauth_version", "1.0"
    auth_header.to_s
  end

  private def signature_key
    String.build do |str|
      CGI.escape @consumer_secret, str
      str << '&'
      if token_secret = @token_secret
        CGI.escape token_secret, str
      end
    end
  end
end
