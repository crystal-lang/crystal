# This file is only required when sockets are used (`require "./event_loop/socket"` in `src/crystal/system/socket.cr`)
#
# It fills `Crystal::EventLoop::Socket` with abstract defs.

abstract class Crystal::EventLoop
  module Socket
  end
end
