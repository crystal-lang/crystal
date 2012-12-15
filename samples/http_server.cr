server = TCPServer.new(8080)
puts "Listening on http://0.0.0.0:8080"

while true
  sock = server.accept
  while !(str = sock.gets).nil?
    if str == "\r\n"
      sock.print "HTTP/1.1 200 OK\r\n"
      sock.print "Content-Type: text/plain\r\n"
      sock.print "Content-Length: 12\r\n"
      sock.print "\r\n"
      sock.print "Hello world!"
      sock.flush
    end
  end
end