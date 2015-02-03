require "./libc"
require "./addrinfo"

class SocketError < Exception
end

# require "./sync/socket"
require "./evented/*"
