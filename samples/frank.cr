require "socket"
require "net/http"

$routes = {} of String => (->String)

def get(path, &block : -> String)
  $routes[path] = block
end

at_exit do
  server = TCPServer.new(8080)
  puts "Listening on http://0.0.0.0:8080"

  while server != nil
    sock = server.accept
    begin
      if request = HTTPRequest.from_io(sock)
        puts "#{request.path} - #{request.headers}"

        if handler = $routes[request.path]?
          begin
            body = handler.call
            response = HTTPResponse.new("HTTP/1.1", 200, "OK", {"Content-Type" => "text/plain"}, body)
          rescue ex
            response = HTTPResponse.new("HTTP/1.1", 500, "Internal Server Error", {"Content-Type" => "text/plain"}, ex.to_s)
          end
        else
          response = HTTPResponse.new("HTTP/1.1", 404, "Not Found", {"Content-Type" => "text/plain"}, "Not Found")
        end
        response.to_io sock
      end
    ensure
      sock.close
    end
  end
end

get "/" do
  "Hello world!"
end

