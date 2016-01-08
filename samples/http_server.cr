require "http/server"

server = HTTP::Server.new "0.0.0.0", 8080 do |context|
  context.response.headers["Content-Type"] = "text/plain"
  context.response.write_body("Hello world!")
end

puts "Listening on http://0.0.0.0:8080"
server.listen
