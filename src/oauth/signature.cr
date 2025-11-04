# :nodoc:
struct OAuth::Signature
  def initialize(@consumer_key : String, @client_shared_secret : String, @oauth_token : String? = nil, @token_shared_secret : String? = nil, @extra_params : Hash(String, String)? = nil)
  end

  def base_string(request : HTTP::Request, tls, ts : String, nonce : String) : String
    base_string request, tls, gather_params(request, ts, nonce)
  end

  def key : String
    String.build do |str|
      URI.encode_www_form @client_shared_secret, str, space_to_plus: false
      str << '&'
      if token_shared_secret = @token_shared_secret
        URI.encode_www_form token_shared_secret, str, space_to_plus: false
      end
    end
  end

  def compute(request : HTTP::Request, tls, ts : String, nonce : String) : String
    base_string = base_string(request, tls, ts, nonce)
    Base64.strict_encode(OpenSSL::HMAC.digest :sha1, key, base_string)
  end

  def authorization_header(request : HTTP::Request, tls, ts : String, nonce : String) : String
    oauth_signature = compute request, tls, ts, nonce

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

  private def base_string(request, tls, normalized_params : String)
    host, port = host_and_port(request, tls)

    String.build do |str|
      str << request.method
      str << '&'
      str << (tls ? "https" : "http")
      str << "%3A%2F%2F"
      URI.encode_www_form host, str, space_to_plus: false
      if port
        str << "%3A"
        str << port
      end
      uri_path = request.path.presence || "/"
      URI.encode_www_form(uri_path, str, space_to_plus: false)
      str << '&'
      URI.encode_www_form(normalized_params, str, space_to_plus: false)
    end
  end

  private def gather_params(request, ts, nonce) : String
    params = URI::Params.new

    # Standard OAuth parameters (all non-nil)
    params.add "oauth_consumer_key", @consumer_key
    params.add "oauth_nonce", nonce
    params.add "oauth_signature_method", "HMAC-SHA1"
    params.add "oauth_timestamp", ts
    params.add "oauth_version", "1.0"

    # Optional token (avoid nil)
    if token = @oauth_token
      params.add "oauth_token", token
    end

    # Add any extra OAuth parameters (custom ones)
    @extra_params.try &.each do |key, value|
      params.add key, value
    end

    # Add query parameters from the URL
    if query = request.query
      URI::Params.parse(query).each do |k, v|
        # v can be String | Nil depending on parser implementation
        params.add k, v.to_s
      end
    end

    # Add x-www-form-urlencoded body parameters if applicable
    if (body = request.body) && request.headers["Content-type"]? == "application/x-www-form-urlencoded"
      form = body.gets_to_end
      URI::Params.parse(form).each do |k, v|
        params.add k, v.to_s
      end
      request.body = form
    end

    oauth_normalize_params(params)
  end

  private def host_and_port(request, tls)
    host_header = request.headers["Host"]
    if colon_index = host_header.index ':'
      host = host_header[0...colon_index]
      port = host_header[colon_index + 1..-1].to_i
      {host, port}
    else
      {host_header, nil}
    end
  end

  private def oauth_rfc3986_encode(s : String) : String
    String.build do |io|
      s.to_slice.each do |b|
        if (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) ||
           (b >= 0x61 && b <= 0x7A) || b == 45 || b == 46 || b == 95 || b == 126
          io << b.chr
        else
          io << '%' << b.to_s(16).upcase.rjust(2, '0')
        end
      end
    end
  end

  private def oauth_normalize_params(params : URI::Params) : String
    pairs = [] of Tuple(String, String)
    params.each do |key, values|
      if values.is_a?(Array)
        values.each { |v| pairs << {oauth_rfc3986_encode(key), oauth_rfc3986_encode(v)} }
      else
        pairs << {oauth_rfc3986_encode(key), oauth_rfc3986_encode(values)}
      end
    end
    pairs.sort_by! { |(k, v)| {k, v} }
    pairs.map { |(k, v)| "#{k}=#{v}" }.join("&")
  end
end
