require "oauth2"
require "http/client"

module OAuth2
  typeof(begin
    client = Client.new "localhost", "client_id", "client_secret", redirect_uri: "uri", authorize_uri: "/baz"
    token = OAuth2::AccessToken::Bearer.new("token", 3600)
    session = Session.new(client, token) { |_| }
    session = Session.new(client, token, Time.utc) { |_| }
    session.authenticate(HTTP::Client.new("localhost"))
  end)
end
