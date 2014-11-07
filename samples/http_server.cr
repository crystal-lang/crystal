require "net/http/server"

server = HTTP::Server.new 8080, do |request|
  HTTP::Response.ok "text/plain", "Hello world!"
end

puts "Listening on http://0.0.0.0:8080"
server.listen
