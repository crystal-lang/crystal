# The OAuth module provides an `OAuth2::Client` as specified
# by [RFC 6749](https://tools.ietf.org/html/rfc6749).
#
# ### Performing HTTP client requests with OAuth2 authentication
#
# Assuming you have an access token, you can setup an `HTTP::Client`
# to be authenticated with OAuth2 using this code:
#
# ```
# require "http/client"
# require "oauth2"
#
# # Here we use a bearer token, but it could be a mac token. We also set the
# # expires in value to 172,800 seconds, or 48 hours
# access_token = OAuth2::AccessToken::Bearer.new("some_access_token", 172_800)
#
# # Create an HTTP::Client
# client = HTTP::Client.new("api.example.com", tls: true)
#
# # Prepare it for using OAuth2 authentication
# access_token.authenticate(client)
#
# # Execute requests as usual: they will be authenticated
# client.get("/some_path")
# ```
#
# This is implemented with `HTTP::Client#before_request` to add an authorization
# header to every request.
#
# ### Obtaining access tokens
#
# See `OAuth2::Client` for an example.
module OAuth2
end
