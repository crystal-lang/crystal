# A server handler is a class which inherits from HTTP::Server::Handler and implements the `call` method.
# You can use a handler to intercept any incoming request and can modify the response. These can be used for request throttling,
# ip-based whitelisting, adding custom headers e.g.
#
# ### A custom server handler
#
# ```
# class CustomHandler < HTTP::Server::Handler
#   def call(context)
#     puts "Doing some stuff"
#     call_next(context)
#   end
# end
# ```
abstract class HTTP::Server::Handler
  property next : Handler | Proc | Nil

  abstract def call(context : HTTP::Server::Context)

  def call_next(context : HTTP::Server::Context)
    if next_handler = @next
      next_handler.call(context)
    else
      context.response.status_code = 404
      context.response.headers["Content-Type"] = "text/plain"
      context.response.puts "Not Found"
    end
  end

  alias Proc = HTTP::Server::Context ->
end

require "./handlers/*"
