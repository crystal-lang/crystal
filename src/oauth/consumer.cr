class OAuth::Consumer
  @host : String
  @consumer_key : String
  @consumer_secret : String
  @secret : String
  @port : Int32
  @scheme : String
  @request_token_uri : String
  @authorize_uri : String
  @access_token_uri : String
  @ssl : Bool

  def initialize(@host : String, @consumer_key : String, @consumer_secret : String,
                 @port : Int32 = 443,
                 @scheme : String = "https",
                 @request_token_uri : String = "/oauth/request_token",
                 @authorize_uri : String = "/oauth/authorize",
                 @access_token_uri : String = "/oauth/access_token")
    @ssl = @scheme == "https"
  end

  def get_request_token(oauth_callback = "oob")
    with_new_http_client(nil, nil, {"oauth_callback": oauth_callback}) do |client|
      response = client.post @request_token_uri
      handle_response(response) do
        RequestToken.from_response(response.body)
      end
    end
  end

  def get_authorize_uri(request_token, oauth_callback = nil)
    query = HTTP::Params.build do |form|
      form.add "oauth_token", request_token.token
      if oauth_callback
        form.add "oauth_callback", oauth_callback
      end
    end

    URI.new(@scheme, @host, @port, @authorize_uri, query).to_s
  end

  def get_access_token(request_token, oauth_verifier, extra_params = nil)
    extra_params ||= {} of String => String
    extra_params["oauth_verifier"] = oauth_verifier
    with_new_http_client(request_token.token, request_token.secret, extra_params) do |client|
      response = client.post @access_token_uri
      handle_response(response) do
        AccessToken.from_response(response.body)
      end
    end
  end

  def authenticate(client : HTTP::Client, token : AccessToken)
    authenticate client, token.token, token.secret, nil
  end

  private def with_new_http_client(oauth_token, token_shared_secret, extra_params)
    client = HTTP::Client.new @host, @port, ssl: @ssl
    authenticate client, oauth_token, token_shared_secret, extra_params
    begin
      yield client
    ensure
      client.close
    end
  end

  private def authenticate(client, oauth_token, token_shared_secret, extra_params)
    client.before_request do |request|
      authenticate client, request, oauth_token, token_shared_secret, extra_params
    end
  end

  private def authenticate(client, request, oauth_token, token_shared_secret, extra_params)
    request.headers["Authorization"] = oauth_header(client, request, oauth_token, token_shared_secret, extra_params)
  end

  private def oauth_header(client, request, oauth_token, token_shared_secret, extra_params)
    ts = Time.now.epoch.to_s
    nonce = SecureRandom.hex

    signature = Signature.new @consumer_key, @consumer_secret, oauth_token, token_shared_secret, extra_params
    signature.authorization_header request, client.ssl?, ts, nonce
  end

  private def handle_response(response)
    case response.status_code
    when 200, 201
      yield
    else
      raise OAuth::Error.new(response)
    end
  end
end
