class OAuth2::Client
  property scope

  def initialize(@host, @client_id, @client_secret,
    @port = 443,
    @scheme = "https",
    @authorize_uri = "/oauth2/authorize",
    @token_uri = "/oauth2/token",
    @redirect_uri = nil)
  end

  def get_authorize_uri(scope = nil, state = nil)
    query = CGI.build_form do |form|
      form.add "client_id", @client_id
      form.add "redirect_uri", @redirect_uri
      form.add "response_type", "code"
      form.add "scope", scope unless scope.nil?
      form.add "state", state unless state.nil?
    end

    URI.new(@scheme, @host, @port, @authorize_uri, query).to_s
  end

  def get_access_token_using_authorization_code(authorization_code)
    get_access_token do |form|
      form.add("redirect_uri", @redirect_uri)
      form.add("grant_type", "authorization_code")
      form.add("code", authorization_code)
    end
  end

  def get_access_token_using_refresh_token(refresh_token, scope = nil)
    get_access_token do |form|
      form.add("grant_type", "refresh_token")
      form.add("refresh_token", refresh_token)
      form.add "scope", scope unless scope.nil?
    end
  end

  def get_access_token_using_client_credentials(scope = nil)
    get_access_token do |form|
      form.add("grant_type", "client_credentials")
      form.add("scope", scope) unless scope.nil?
    end
  end

  private def get_access_token
    body = CGI.build_form do |form|
      form.add("client_id", @client_id)
      form.add("client_secret", @client_secret)
      yield form
    end

    response = HTTP::Client.post_form(token_uri, body)
    case response.status_code
    when 200, 201
      OAuth2::AccessToken.from_json(response.body)
    else
      raise OAuth2::Error.from_json(response.body)
    end
  end

  private def token_uri
    URI.new(@scheme, @host, @port, @token_uri).to_s
  end
end
