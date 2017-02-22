require "http/server"

handler = HTTP::StaticFileHandler.new(".")

# server = HTTP::Server.new "0.0.0.0", 8080 do |context|
#   context.response.headers["Content-Type"] = "text/plain"
#   context.response.print("Hello world!")
# end

server = HTTP::Server.new "0.0.0.0", 8080, handler

puts "Listening on http://0.0.0.0:8080"
server.listen
