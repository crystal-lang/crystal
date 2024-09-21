# An OAuth2 client.
#
# For a quick example of how to authenticate an `HTTP::Client` with OAuth2 if
# you already have an access token, check the `OAuth2` module description.
#
# This class also provides methods to build authorize URIs
# and get access tokens with different methods, as specified by
# [RFC 6749](https://tools.ietf.org/html/rfc6749).
#
# ### Example
#
# ```
# require "oauth2"
#
# client_id = "some_client_id"
# client_secret = "some_client_secret"
# redirect_uri = "http://some.callback"
#
# # Create oauth client, optionally pass custom URIs if needed,
# # if the authorize or token URIs are not the standard ones
# # (they can also be absolute URLs)
# oauth2_client = OAuth2::Client.new("api.example.com", client_id, client_secret,
#   redirect_uri: redirect_uri)
#
# # Build an authorize URI
# authorize_uri = oauth2_client.get_authorize_uri
#
# # Redirect the user to `authorize_uri`...
# #
# # ...
# #
# # When http://some.callback is hit, once the user authorized the access,
# # we resume our logic to finally get an access token. The callback URL
# # should receive an `authorization_code` parameter that we need to use.
# authorization_code = request.params["code"]
#
# # Get the access token
# access_token = oauth2_client.get_access_token_using_authorization_code(authorization_code)
#
# # Probably save the access token for reuse... This can be done
# # with `to_json` and `from_json`.
#
# # Use the token to authenticate an HTTP::Client
# client = HTTP::Client.new("api.example.com", tls: true)
# access_token.authenticate(client)
#
# # And do requests as usual
# client.get "/some_path"
#
# # If the token expires, we can refresh it
# new_access_token = oauth2_client.get_access_token_using_refresh_token(access_token.refresh_token)
# ```
#
# You can also use an `OAuth2::Session` to automatically refresh expired
# tokens before each request.
class OAuth2::Client
  DEFAULT_HEADERS = HTTP::Headers{
    "Accept"       => "application/json",
    "Content-Type" => "application/x-www-form-urlencoded",
  }

  # Sets the `HTTP::Client` to use with this client.
  setter http_client : HTTP::Client?

  # Gets the redirect_uri
  getter redirect_uri : String?

  # Returns the `HTTP::Client` to use with this client.
  #
  # By default, this returns a new instance every time. To reuse the same instance,
  # one can be assigned with `#http_client=`.
  def http_client : HTTP::Client
    @http_client || HTTP::Client.new(token_uri)
  end

  # Creates an OAuth client.
  #
  # Any or all of the customizable URIs *authorize_uri* and
  # *token_uri* can be relative or absolute.
  # If they are relative, the given *host*, *port* and *scheme* will be used.
  # If they are absolute, the absolute URL will be used.
  #
  # As per https://tools.ietf.org/html/rfc6749#section-2.3.1,
  # `AuthScheme::HTTPBasic` is the default *auth_scheme* (the mechanism used to
  # transmit the client credentials to the server). `AuthScheme::RequestBody` should
  # only be used if the server does not support HTTP Basic.
  def initialize(@host : String, @client_id : String, @client_secret : String,
                 @port : Int32? = nil,
                 @scheme = "https",
                 @authorize_uri = "/oauth2/authorize",
                 @token_uri = "/oauth2/token",
                 @redirect_uri : String? = nil,
                 @auth_scheme : AuthScheme = :http_basic)
  end

  # Builds an authorize URI, as specified by
  # [RFC 6749, Section 4.1.1](https://tools.ietf.org/html/rfc6749#section-4.1.1).
  def get_authorize_uri(scope = nil, state = nil) : String
    get_authorize_uri(scope, state) { }
  end

  # Builds an authorize URI, as specified by
  # [RFC 6749, Section 4.1.1](https://tools.ietf.org/html/rfc6749#section-4.1.1).
  #
  # Yields an `URI::Params::Builder` to add extra parameters other than those
  # defined by the standard.
  def get_authorize_uri(scope = nil, state = nil, &block : URI::Params::Builder ->) : String
    uri = URI.parse(@authorize_uri)

    # Use the default URI if it's not an absolute one
    unless uri.host
      uri = URI.new(@scheme, @host, @port, @authorize_uri)
    end

    uri.query = URI::Params.build do |form|
      form.add("client_id", @client_id)
      form.add("redirect_uri", @redirect_uri)
      form.add("response_type", "code")
      form.add("scope", scope) unless scope.nil?
      form.add("state", state) unless state.nil?
      uri.query_params.each do |key, value|
        form.add(key, value)
      end
      yield form
    end

    uri.to_s
  end

  # Gets an access token using an authorization code, as specified by
  # [RFC 6749, Section 4.1.3](https://tools.ietf.org/html/rfc6749#section-4.1.3).
  def get_access_token_using_authorization_code(authorization_code : String) : AccessToken
    get_access_token do |form|
      form.add("redirect_uri", @redirect_uri)
      form.add("grant_type", "authorization_code")
      form.add("code", authorization_code)
    end
  end

  # Gets an access token using the resource owner credentials, as specified by
  # [RFC 6749, Section 4.3.2](https://tools.ietf.org/html/rfc6749#section-4.3.2).
  def get_access_token_using_resource_owner_credentials(username : String, password : String, scope = nil) : AccessToken
    get_access_token do |form|
      form.add("grant_type", "password")
      form.add("username", username)
      form.add("password", password)
      form.add("scope", scope) unless scope.nil?
    end
  end

  # Gets an access token using client credentials, as specified by
  # [RFC 6749, Section 4.4.2](https://tools.ietf.org/html/rfc6749#section-4.4.2).
  def get_access_token_using_client_credentials(scope = nil) : AccessToken
    get_access_token do |form|
      form.add("grant_type", "client_credentials")
      form.add("scope", scope) unless scope.nil?
    end
  end

  # Gets an access token using a refresh token, as specified by
  # [RFC 6749, Section 6](https://tools.ietf.org/html/rfc6749#section-6).
  def get_access_token_using_refresh_token(refresh_token, scope = nil) : AccessToken
    get_access_token do |form|
      form.add("grant_type", "refresh_token")
      form.add("refresh_token", refresh_token)
      form.add("scope", scope) unless scope.nil?
    end
  end

  # Makes a token exchange request with custom headers and form fields
  def make_token_request(&block : URI::Params::Builder, HTTP::Headers -> _) : HTTP::Client::Response
    headers = DEFAULT_HEADERS.dup
    body = URI::Params.build do |form|
      case @auth_scheme
      when .request_body?
        form.add("client_id", @client_id)
        form.add("client_secret", @client_secret)
      when .http_basic?
        headers.add(
          "Authorization",
          "Basic #{Base64.strict_encode("#{@client_id}:#{@client_secret}")}"
        )
      end
      yield form, headers
    end

    http_client.post token_uri.request_target, form: body, headers: headers
  end

  private def get_access_token(&) : AccessToken
    response = make_token_request do |form, _headers|
      yield form
    end
    case response.status
    when .ok?, .created?
      OAuth2::AccessToken.from_json(response.body)
    else
      raise OAuth2::Error.new(response.body)
    end
  end

  private def token_uri : URI
    uri = URI.parse(@token_uri)
    if uri.host
      uri
    else
      URI.new(@scheme, @host, @port, @token_uri)
    end
  end
end
