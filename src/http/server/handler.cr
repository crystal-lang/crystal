# A handler is a class which inherits from HTTP::Handler and implements the `call` method.
# You can use a handler to intercept any incoming request and can modify the response. These can be used for request throttling,
# ip-based whitelisting, adding custom headers e.g.
#
# ### A custom handler
#
# ```
# class CustomHandler < HTTP::Handler
#   def call(context)
#     puts "Doing some stuff"
#     call_next(context)
#   end
# end
# ```
abstract class HTTP::Handler
  property :next

  def call_next(context : HTTP::Server::Context)
    @next.try &.call(context)
  end

  alias Proc = HTTP::Server::Context ->
end

require "./handlers/*"
