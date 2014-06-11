require "socket"
require "net/http"

def get(path, &block : -> String)
  $frank_handler.add_route(path, block)
end

class LogHandler < HTTP::Handler
  def call(request)
    puts "#{request.path} - #{request.headers}"
    @next.not_nil!.call request
  end
end

class FrankHandler < HTTP::Handler
  def initialize
    @routes = {} of String => (->String)
  end

  def call(request)
    if handler = @routes[request.path]?
      begin
        HTTP::Response.new("HTTP/1.1", 200, "OK", {"Content-Type" => "text/plain"}, handler.call)
      rescue ex
        HTTP::Response.new("HTTP/1.1", 500, "Internal Server Error", {"Content-Type" => "text/plain"}, ex.to_s)
      end
    else
      HTTP::Response.new("HTTP/1.1", 404, "Not Found", {"Content-Type" => "text/plain"}, "Not Found")
    end
  end

  def add_route(path, handler)
    @routes[path] = handler
  end
end

$frank_handler = FrankHandler.new

at_exit do
  handlers = [] of HTTP::Handler
  handlers << LogHandler.new
  handlers << $frank_handler
  server = HTTP::Server.new(8080, HTTP::Server.build_middleware handlers)

  puts "Listening on http://0.0.0.0:8080"
  server.listen
end

get "/" do
  "Hello world!"
end

