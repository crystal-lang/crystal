require "./context"

# A handler is a class which includes `HTTP::Handler` and implements the `call` method.
# You can use a handler to intercept any incoming request and can modify the response.
# These can be used for request throttling, ip-based filtering, adding custom headers e.g.
#
# NOTE: To use `Handler`, you must explicitly import it with `require "http/server/handler"`
#
# ### A custom handler
#
# ```
# require "http/server/handler"
#
# class CustomHandler
#   include HTTP::Handler
#
#   def call(context)
#     puts "Doing some stuff"
#     call_next(context)
#   end
# end
# ```
module HTTP::Handler
  property next : Handler | HandlerProc | Nil

  abstract def call(context : HTTP::Server::Context)

  def call_next(context : HTTP::Server::Context)
    if next_handler = @next
      next_handler.call(context)
    else
      context.response.respond_with_status(:not_found)
    end
  end

  alias HandlerProc = HTTP::Server::Context ->
end

require "./handlers/*"
