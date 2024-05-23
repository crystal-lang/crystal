# This file is only required when sockets are used (`require "./event_loop/socket"` in `src/crystal/system/socket.cr`)
#
# It fills `Crystal::EventLoop::Socket` with abstract defs.

abstract class Crystal::EventLoop
  module Socket
    # Reads at least one byte from the socket into *slice*.
    #
    # Blocks the current fiber if no data is available for reading, continuing
    # when available. Otherwise returns immediately.
    #
    # Returns the number of bytes read (up to `slice.size`).
    # Returns 0 when the socket is closed and not data available.
    abstract def read(socket : ::Socket, slice : Bytes) : Int32

    # Writes at least one byte from *slice* to the socket.
    #
    # Blocks the current fiber if the socket is not ready for writing,
    # continuing when it is. Otherwise returns immediately.
    #
    # Returns the number of bytes written (up to `slice.size`).
    abstract def write(socket : ::Socket, slice : Bytes) : Int32

    # Closes the socket.
    abstract def close(socket : ::Socket) : Nil
  end
end
