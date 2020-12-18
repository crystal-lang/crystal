#! /usr/bin/env crystal
#
# This helper runs a default `HTTP::Server` instance and checks its behaviour
# using [testssl.sh](https://testssl.sh/).
# testssl.sh is a tool for validating TLS implementations.

require "http"
require "../spec/support/ssl"

# This is needed for the ssl_context_pair helper
def datapath(*components)
  File.join("spec", "std", "data", *components)
end

server = HTTP::Server.new do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world!"
end
server_context, client_context = ssl_context_pair
address = server.bind_tls "0.0.0.0", 0, server_context

puts "== Starting HTTP server at #{address}"

spawn do
  puts "== Running testssl.sh"
  puts "This may take some time..."

  Process.run("testssl.sh", %w(--parallel --nodns none --color 2) << address.to_s,
    output: :inherit, error: :inherit)

  server.close
end

server.listen
