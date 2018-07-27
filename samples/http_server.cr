# A very basic HTTP server
require "http/server"

server = HTTP::Server.new do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end

puts "Listening on http://127.0.0.1:8080"
server.listen(8080)
