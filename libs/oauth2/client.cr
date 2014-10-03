class OAuth2::Client
  property scope
  property authorization_code

  def initialize(@host, @client_id, @client_secret,
    @port = 443,
    @scheme = "https",
    @authorization_uri = "/oauth2/authorize",
    @token_endpoint = "/oauth2/token",
    @redirect_uri = nil)
  end

  def authorization_uri(scope = nil)
    query = CGI.build_form do |form|
      form.add "client_id", @client_id
      form.add "redirect_uri", @redirect_uri
      form.add "response_type", "code"
      form.add "scope", scope
    end

    URI.new(@scheme, @host, @port, @authorization_uri, query).to_s
  end

  def request_access_token
    body = CGI.build_form do |form|
      form
        .add("client_id", @client_id)
        .add("client_secret", @client_secret)
        .add("redirect_uri", @redirect_uri)
        .add("grant_type", "authorization_code")
        .add("code", @authorization_code)
    end

    response = HTTP::Client.post_form(token_endpoint_uri, body)
    case response.status_code
    when 200, 201
      OAuth2::AccessToken.from_json(response.body.not_nil!)
    else
      raise OAuth2::Error.from_json(response.body.not_nil!)
    end
  end

  private def token_endpoint_uri
    URI.new(@scheme, @host, @port, @token_endpoint).to_s
  end
end
