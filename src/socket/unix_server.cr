require "./unix_socket"

# A local interprocess communication server socket.
#
# Only available on UNIX and UNIX-like operating systems.
#
# Example usage:
# ```
# server = UNIXServer.new("/tmp/myapp.sock")
# message = server.gets
# server.puts message
# ```
class UNIXServer < UNIXSocket
  # Creates a named UNIX socket, listening on a filesystem pathname.
  #
  # Always deletes any existing filesystam pathname first, in order to cleanup
  # any leftover socket file.
  #
  # The server is of stream type by default, but this can be changed for
  # another type. For example datagram messages:
  # ```
  # UNIXServer.new("/tmp/dgram.sock", Socket::Type::DGRAM)
  # ```
  def initialize(@path : String, type : Type = Type::STREAM, backlog = 128)
    addr = LibC::SockaddrUn.new
    addr.sun_family = typeof(addr.sun_family).new(Family::UNIX)

    if path.bytesize + 1 > addr.sun_path.size
      raise ArgumentError.new("Path size exceeds the maximum size of #{addr.sun_path.size - 1} bytes")
    end
    addr.sun_path.to_unsafe.copy_from(path.to_unsafe, path.bytesize + 1)

    super create_socket(Family::UNIX, type, 0)

    if LibC.bind(@fd, (pointerof(addr).as(LibC::Sockaddr*)), sizeof(LibC::SockaddrUn)) != 0
      close
      raise Errno.new("Error binding UNIX server at #{path}")
    end

    if LibC.listen(@fd, backlog) != 0
      close
      raise Errno.new("Error listening UNIX server at #{path}")
    end
  end

  # Creates a new UNIX server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(path, type : Type = Type::STREAM, backlog = 128)
    server = new(path, type, backlog)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Accepts an incoming connection and yields the client socket to the block.
  # Eventually closes the connection when the block returns.
  #
  # Returns the value of the block. If the server is closed after invoking this
  # method, an `IO::Error` (closed stream) exception will be raised.
  def accept
    sock = accept
    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Accepts an incoming connection and yields the client socket to the block.
  # Eventualy closes the connection when the block returns.
  #
  # Returns the value of the block or `nil` if the server is closed after
  # invoking this method.
  def accept?
    sock = accept?
    return unless sock

    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Accepts an incoming connection.
  #
  # Returns the client socket. Raises an `IO::Error` (closed stream) exception
  # if the server is closed after invoking this method.
  def accept : UNIXSocket
    accept? || raise IO::Error.new("closed stream")
  end

  # Accepts an incoming connection.
  #
  # Returns the client socket or `nil` if the server is closed after invoking
  # this method.
  def accept? : UNIXSocket?
    loop do
      client_fd = LibC.accept(fd, out client_addr, out client_addrlen)
      if client_fd == -1
        return nil if closed?

        if Errno.value == Errno::EAGAIN
          wait_readable
        else
          raise Errno.new("Error accepting socket at #{path}")
        end
      else
        sock = UNIXSocket.new(client_fd)
        sock.sync = sync?
        return sock
      end
    end
  end

  # Closes the socket and deletes the filesystem pathname.
  def close
    super
  ensure
    if path = @path
      File.delete(path) if File.exists?(path)
      @path = nil
    end
  end
end
