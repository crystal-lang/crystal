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
    # Returns 0 when the socket is closed and no data available.
    #
    # Use `#send_to` for sending a message to a specific target address.
    abstract def read(socket : ::Socket, slice : Bytes) : Int32

    # Writes at least one byte from *slice* to the socket.
    #
    # Blocks the current fiber if the socket is not ready for writing,
    # continuing when ready. Otherwise returns immediately.
    #
    # Returns the number of bytes written (up to `slice.size`).
    #
    # Use `#receive_from` for capturing the source address of a message.
    abstract def write(socket : ::Socket, slice : Bytes) : Int32

    # Accepts an incoming TCP connection on the socket.
    #
    # Blocks the current fiber if no connection is waiting, continuing when one
    # becomes available. Otherwise returns immediately.
    #
    # Returns a handle to the socket for the new connection.
    abstract def accept(socket : ::Socket) : ::Socket::Handle?

    # Opens a connection on *socket* to the target *address*.
    #
    # Blocks the current fiber and continues when the connection is established.
    #
    # Returns `IO::Error` in case of an error. The caller is responsible for
    # raising it as an exception if necessary.
    abstract def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : ::Time::Span?) : IO::Error?

    # Sends at least one byte from *slice* to the socket with a target address
    # *address*.
    #
    # Blocks the current fiber if the socket is not ready for writing,
    # continuing when ready. Otherwise returns immediately.
    #
    # Returns the number of bytes sent (up to `slice.size`).
    abstract def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32

    # Receives at least one byte from the socket into *slice*, capturing the
    # source address.
    #
    # Blocks the current fiber if no data is available for reading, continuing
    # when available. Otherwise returns immediately.
    #
    # Returns a tuple containing the number of bytes received (up to `slice.size`)
    # and the source address.
    abstract def receive_from(socket : ::Socket, slice : Bytes) : Tuple(Int32, ::Socket::Address)

    # Closes the socket.
    abstract def close(socket : ::Socket) : Nil
  end
end
