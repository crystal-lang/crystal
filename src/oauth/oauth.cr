# The OAuth module provides an `OAuth::Consumer` as specified by
# [RFC 5849](https://tools.ietf.org/html/rfc5849).
#
# ### Performing HTTP client requests with OAuth authentication
#
# Assuming you have an access token, its secret, the consumer key and the consumer secret,
# you can setup an `HTTP::Client` to be authenticated with OAuth using this code:
#
# ```
# require "http/client"
# require "oauth"
#
# token = "some_token"
# secret = "some_secret"
# consumer_key = "some_consumer_key"
# consumer_secret = "some_consumer_secret"
#
# # Create an HTTP::Client as usual
# client = HTTP::Client.new("api.example.com", tls: true)
#
# # Prepare it for using OAuth authentication
# OAuth.authenticate(client, token, secret, consumer_key, consumer_secret)
#
# # Execute requests as usual: they will be authenticated
# client.get("/some_path")
# ```
#
# This is implemented with `HTTP::Client#before_request` to add an authorization
# header to every request.
#
# Alternatively, you can create an `OAuth::Consumer` and then invoke its
# `OAuth::Consumer#authenticate` method, or create an `OAuth::AccessToken`
# and invoke its `OAuth::AccessToken#authenticate`.
#
# ### Obtaining access tokens
#
# See `OAuth::Consumer` for an example.
module OAuth
  # Sets up an `HTTP::Client` to add an OAuth authorization header to every request performed.
  # Check this module's docs for an example usage.
  def self.authenticate(client : HTTP::Client, token, token_secret, consumer_key, consumer_secret, extra_params = nil) : Nil
    client.before_request do |request|
      authenticate client, request, token, token_secret, consumer_key, consumer_secret, extra_params
    end
  end

  private def self.authenticate(client, request, token, token_secret, consumer_key, consumer_secret, extra_params)
    request.headers["Authorization"] = oauth_header(client, request, token, token_secret, consumer_key, consumer_secret, extra_params)
  end

  private def self.oauth_header(client, request, token, token_secret, consumer_key, consumer_secret, extra_params)
    ts = Time.now.epoch.to_s
    nonce = Random::Secure.hex

    signature = Signature.new consumer_key, consumer_secret, token, token_secret, extra_params
    signature.authorization_header request, client.tls?, ts, nonce
  end
end
