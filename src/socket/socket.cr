require "./libc"
require "./addrinfo"

class SocketError < Exception
end

ifdef evented
  require "./evented/*"
else
  require "./sync/socket"
end

require "./common/*"
