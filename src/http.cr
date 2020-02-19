require "uri"
{% unless flag?(:win32) %}
  require "./http/client"
  require "./http/server"
{% end %}
require "./http/common"

# The HTTP module contains `HTTP::Client`, `HTTP::Server` and `HTTP::WebSocket` implementations.
module HTTP
end
