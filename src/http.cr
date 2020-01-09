require "uri"
{% if flag?(:win32) %}
  require "./http/common"
{% else %}
  require "./http/**"
{% end %}

# The HTTP module contains `HTTP::Client`, `HTTP::Server` and `HTTP::WebSocket` implementations.
module HTTP
end
