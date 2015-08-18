require "socket"
require "socket/tcp_socket"

socket = TCPSocket.new "127.0.0.1", 9000
10.times do |i|
  socket.puts "#{i}"
  puts "server responce #{socket.gets}"
  sleep 0.5
end

