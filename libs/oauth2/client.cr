class OAuth2::Client
  property scope
  property authorization_code

  def initialize(@host, @client_id, @client_secret,
    @port = 443,
    @scheme = "https",
    @authorize_uri = "/oauth2/authorize",
    @token_uri = "/oauth2/token",
    @redirect_uri = nil)
  end

  def authorize_uri(scope = nil)
    query = CGI.build_form do |form|
      form.add "client_id", @client_id
      form.add "redirect_uri", @redirect_uri
      form.add "response_type", "code"
      form.add "scope", scope
    end

    URI.new(@scheme, @host, @port, @authorize_uri, query).to_s
  end

  def get_access_token
    body = CGI.build_form do |form|
      form
        .add("client_id", @client_id)
        .add("client_secret", @client_secret)
        .add("redirect_uri", @redirect_uri)
        .add("grant_type", "authorization_code")
        .add("code", @authorization_code)
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
