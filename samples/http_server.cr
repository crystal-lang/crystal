require "http/server"

server = HTTP::Server.new do |context|
  context.response.headers["Content-Type"] = "text/plain"
  context.response.print("Hello world!")
end

puts "Listening on http://0.0.0.0:8080"
server.listen "0.0.0.0", 8080
