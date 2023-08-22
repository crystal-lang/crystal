# Enum of supported mechanisms used to pass credentials to the server.
#
# According to https://tools.ietf.org/html/rfc6749#section-2.3.1:
#
# > "Including the client credentials in the request-body using the
# > two parameters is NOT RECOMMENDED and SHOULD be limited to
# > clients unable to directly utilize the HTTP Basic authentication
# > scheme (or other password-based HTTP authentication schemes)."
#
# Therefore, HTTP Basic is preferred, and Request Body should only
# be used if the server does not support HTTP Basic.
enum OAuth2::AuthScheme
  HTTPBasic
  RequestBody
end
