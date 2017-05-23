require "socket"

# goes with tcp_client.cr

def process(client)
  client_addr = client.remote_address
  puts "#{client_addr} connected"

  while msg = client.read_line
    puts "#{client_addr} msg '#{msg}'"
    client.puts msg
  end
rescue IO::EOFError
  puts "#{client_addr} disconnected"
ensure
  client.close
end

server = TCPServer.new "127.0.0.1", 9000
puts "listen on 127.0.0.1:9000"
loop { spawn process(server.accept) }
