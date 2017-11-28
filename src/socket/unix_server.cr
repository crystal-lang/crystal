require "./unix_socket"

# A local interprocess communication server socket.
#
# Only available on UNIX and UNIX-like operating systems.
#
# Example usage:
# ```
# require "socket"
#
# def handle_client(client)
#   message = client.gets
#   client.puts message
# end
#
# server = UNIXServer.new("/tmp/myapp.sock")
# while client = server.accept?
#   spawn handle_client(client)
# end
# ```
class UNIXServer < UNIXSocket
  include Socket::Server

  # Creates a named UNIX socket, listening on a filesystem pathname.
  #
  # Always deletes any existing filesystam pathname first, in order to cleanup
  #
  # Note: An abstract UNIX server act on virtual files, thus not creating nor deleting anything.
  #
  # The server is of stream type by default, but this can be changed for
  # another type. For example datagram messages:
  # ```
  # UNIXServer.new("/tmp/dgram.sock", Socket::Type::DGRAM)
  # ```
  def initialize(path : String, type : Type = Type::STREAM, backlog = 128)
    super(Family::UNIX, type)

    addr = UNIXAddress.new(path)
    @abstract = addr.abstract?
    @path = addr.path
    bind(addr) do |error|
      close(delete: false)
      raise error
    end

    listen(backlog) do |error|
      close
      raise error
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

  # Accepts an incoming connection.
  #
  # Returns the client socket or `nil` if the server is closed after invoking
  # this method.
  def accept? : UNIXSocket?
    if client_fd = accept_impl
      sock = UNIXSocket.new(client_fd, type, @abstract)
      sock.sync = sync?
      sock
    end
  end

  # Closes the socket, then deletes the filesystem pathname if it exists.
  def close(delete = true)
    super()
  ensure
    if !abstract? && delete && (path = @path)
      File.delete(path) if File.exists?(path)
    end
    @path = nil
  end
end
