# An OAuth2 session makes it easy to implement APIs that need to refresh
# an access token once its expired before executing an HTTP request.
class OAuth2::Session
  getter oauth2_client : Client
  getter access_token : AccessToken
  getter expires_at : Time?

  # Creates an `OAuth2::Session`.
  #
  # Params:
  #   * *oauth2_client*: the OAuth2::Client used to refresh an access token.
  #   * *access_token*: the OAuth2::AccessToken to make requests.
  #   * *expires_at*: the Time when the access token expires.
  #   * *callback*: invoked when an access token is refreshed, giving you a chance to persist it.
  def initialize(@oauth2_client : Client, @access_token : AccessToken, @expires_at = Time.utc_now, &@callback : OAuth2::Session ->)
  end

  # Authenticates an `HTTP::Client`, refreshing the access token if it is expired.
  #
  # Invoke this method on an `HTTP::Client` before executing an HTTP request.
  def authenticate(http_client)
    check_refresh_token
    @access_token.authenticate http_client
  end

  private def check_refresh_token
    if access_token_expired?
      refresh_access_token

      @callback.call(self)
    end
  end

  private def access_token_expired?
    if expires_at = @expires_at
      Time.utc_now >= expires_at
    else
      false
    end
  end

  private def refresh_access_token
    old_access_token = @access_token
    @access_token = @oauth2_client.get_access_token_using_refresh_token(@access_token.refresh_token)

    expires_in = @access_token.expires_in
    if expires_in
      @expires_at = Time.utc_now + expires_in.seconds
    else
      # If there's no expires_in in the access token, we assume it never expires
      @expires_at = nil
    end

    @access_token.refresh_token ||= old_access_token.refresh_token
  end
end
