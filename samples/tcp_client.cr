require "socket"

# goes with tcp_server.cr

socket = TCPSocket.new "127.0.0.1", 9000
10.times do |i|
  socket.puts i
  puts "server response #{socket.gets}"
  sleep 0.5
end
