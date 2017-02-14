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
  # Creates an OAuth client.
  #
  # Any or all of the customizable URIs *authorize_uri* and
  # *token_uri* can be relative or absolute.
  # If they are relative, the given *host*, *port* and *scheme* will be used.
  # If they are absolute, the absolute URL will be used.
  def initialize(@host : String, @client_id : String, @client_secret : String,
                 @port = 443,
                 @scheme = "https",
                 @authorize_uri = "/oauth2/authorize",
                 @token_uri = "/oauth2/token",
                 @redirect_uri : String? = nil)
  end

  # Builds an authorize URI, as specified by
  # [RFC 6749, Section 4.1.1](https://tools.ietf.org/html/rfc6749#section-4.1.1).
  def get_authorize_uri(scope = nil, state = nil) : String
    get_authorize_uri(scope, state) { }
  end

  # Builds an authorize URI, as specified by
  # [RFC 6749, Section 4.1.1](https://tools.ietf.org/html/rfc6749#section-4.1.1).
  #
  # Yields an `HTTP::Params::Builder` to add extra parameters other than those
  # defined by the standard.
  def get_authorize_uri(scope = nil, state = nil, &block : HTTP::Params::Builder ->) : String
    uri = URI.parse(@authorize_uri)

    # Use the default URI if it's not an absolute one
    unless uri.host
      uri = URI.new(@scheme, @host, @port, @authorize_uri)
    end

    uri.query = HTTP::Params.build do |form|
      form.add "client_id", @client_id
      form.add "redirect_uri", @redirect_uri
      form.add "response_type", "code"
      form.add "scope", scope unless scope.nil?
      form.add "state", state unless state.nil?
      if query = uri.query
        HTTP::Params.parse(query).each do |key, value|
          form.add key, value
        end
      end
      yield form
    end

    uri.to_s
  end

  # Gets an access token using an authorization code, as specified by
  # [RFC 6749, Section 4.1.1](https://tools.ietf.org/html/rfc6749#section-4.1.3).
  def get_access_token_using_authorization_code(authorization_code) : AccessToken
    get_access_token do |form|
      form.add("redirect_uri", @redirect_uri)
      form.add("grant_type", "authorization_code")
      form.add("code", authorization_code)
    end
  end

  # Gets an access token using a refresh token, as specified by
  # [RFC 6749, Section 6](https://tools.ietf.org/html/rfc6749#section-6).
  def get_access_token_using_refresh_token(refresh_token, scope = nil) : AccessToken
    get_access_token do |form|
      form.add("grant_type", "refresh_token")
      form.add("refresh_token", refresh_token)
      form.add "scope", scope unless scope.nil?
    end
  end

  # Gets an access token using client credentials, as specified by
  # [RFC 6749, Section 4.4.2](https://tools.ietf.org/html/rfc6749#section-4.4.2).
  def get_access_token_using_client_credentials(scope = nil)
    get_access_token do |form|
      form.add("grant_type", "client_credentials")
      form.add("scope", scope) unless scope.nil?
    end
  end

  private def get_access_token
    body = HTTP::Params.build do |form|
      form.add("client_id", @client_id)
      form.add("client_secret", @client_secret)
      yield form
    end

    headers = HTTP::Headers{
      "Accept" => "application/json",
    }

    response = HTTP::Client.post_form(token_uri, body, headers)
    case response.status_code
    when 200, 201
      OAuth2::AccessToken.from_json(response.body)
    else
      raise OAuth2::Error.from_json(response.body)
    end
  end

  private def token_uri
    uri = URI.parse(@token_uri)

    if uri.host
      # If it's an absolute URI, use that one
      @token_uri
    else
      # Otherwise use the default one
      URI.new(@scheme, @host, @port, @token_uri).to_s
    end
  end
end
