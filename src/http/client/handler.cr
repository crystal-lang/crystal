# A client handler is a class which inherits from HTTP::Client::Handler and implements the `call` method.
# You can use a handler to intercept any outgoing requests or incoming responses and modify it. These can be used for request redirecting,
# session handling e.g.
#
# ### A custom client handler
#
# ```
# class CustomHandler < HTTP::Client::Handler
#   def call(context)
#     puts "Doing some stuff"
#     call_next(context)
#   end
# end
# ```
abstract class HTTP::Client::Handler

  property next : Handler | Nil

  def call(request : HTTP::Request) : HTTP::Request
    call_next(request)
  end

  def call(response : HTTP::Client::Response) : HTTP::Client::Response
    call_next(response)
  end

  def call_next(context : HTTP::Client::Response | HTTP::Request)
    if next_handler = @next
      next_handler.call(context)
    else
      context
    end
  end
end

require "./handlers/*"
