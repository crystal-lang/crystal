require "socket"
require "socket/tcp_server"

def process(client)
  client_addr = "#{client.peeraddr.ip_address}:#{client.peeraddr.ip_port}"
  puts "#{client_addr} connected"
  while msg = client.read_line
    puts "#{client_addr} msg '#{msg.chop}'"
    client << msg
  end
rescue 
  puts "#{client_addr} dissconnected"
end

server = TCPServer.new "127.0.0.1", 9000
puts "listen on 127.0.0.1:9000"
loop do
  if client = server.accept
    spawn { process(client) }
  end
end
