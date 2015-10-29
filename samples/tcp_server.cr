require "socket"

# goes with tcp_client.cr

def process(client)
  client_addr = "#{client.peeraddr.address}:#{client.peeraddr.port}"
  puts "#{client_addr} connected"

  while msg = client.read_line
    puts "#{client_addr} msg '#{msg.chop}'"
    client << msg
  end
rescue IO::EOFError
  puts "#{client_addr} dissconnected"
ensure
  client.close
end

server = TCPServer.new "127.0.0.1", 9000
puts "listen on 127.0.0.1:9000"
loop { spawn process(server.accept) }
