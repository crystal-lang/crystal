require "socket"

# goes with daemonize/tcp_server_daemon.cr

socket = TCPSocket.new "127.0.0.1", 9000
10.times do |i|
  socket.puts "#{i}"
  puts "server response #{socket.gets}"
  sleep 0.5
end

socket.puts "exit"
