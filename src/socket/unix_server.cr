require "./unix_socket"
require "./server"

# A local interprocess communication (UNIX socket) server socket.
#
# Only available on UNIX and UNIX-like operating systems.
#
# Usage example:
# ```
# require "socket/unix_server"
#
# def handle_client(client)
#   message = client.gets
#   client.puts message
# end
#
# UNIXServer.open("/tmp/myapp.sock") do |server|
#   while client = server.accept?
#     spawn handle_client(client)
#   end
# end
# ```
struct UNIXServer
  include Socket::Server

  # Returns the raw socket wrapped by this UNIX server.
  getter raw : Socket::Raw

  @address : Socket::UNIXAddress

  # Creates a `UNIXServer` from a raw socket.
  def initialize(@raw : Socket::Raw, @address : Socket::UNIXAddress)
  end

  # Creates a named UNIX socket listening on a filesystem pathname.
  #
  # Always deletes any existing filesystam pathname first, in order to cleanup
  # any leftover socket file.
  #
  # ```
  # UNIXServer.new("/tmp/dgram.sock")
  # ```
  def self.new(path : String, *, mode : File::Permissions? = nil, backlog : Int32 = 128) : UNIXServer
    new(Socket::UNIXAddress.new(path), mode: mode, backlog: backlog)
  end

  # Creates a named UNIX socket listening on *address*.
  #
  # Always deletes any existing filesystam pathname first, in order to cleanup
  # any leftover socket file.
  #
  # ```
  # UNIXServer.new(Socket::UNIXAddress.new("/tmp/dgram.sock"))
  # ```
  def self.new(address : Socket::UNIXAddress, *, mode : File::Permissions? = nil, backlog = 128) : UNIXServer
    base = Socket::Raw.new(Socket::Family::UNIX, Socket::Type::STREAM, Socket::Protocol::IP)
    base.bind(address)
    base.listen(backlog: backlog)

    if mode
      File.chmod(address.path, mode)
    end

    new(base, address)
  end

  # Creates a named UNIX socket listening on *path* and yields it to the block.
  # Eventually closes the server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(address : String | Socket::UNIXAddress, *, mode : File::Permissions? = nil, backlog = 128)
    socket = new(address, mode: mode, backlog: backlog)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  Socket.delegate_close
  Socket.delegate_sync

  # Accepts an incoming connection.
  #
  # Returns the client `UNIXSocket` or `nil` if the server is closed after invoking
  # this method.
  #
  # ```
  # require "socket/unix_server"
  #
  # UNIXServer.open("path/to_my_socket") do |server|
  #   loop do
  #     if socket = server.accept?
  #       # handle the client in a fiber
  #       spawn handle_connection(socket)
  #     else
  #       # another fiber closed the server
  #       break
  #     end
  #   end
  # end
  # ```
  def accept? : UNIXSocket?
    if client = @raw.accept?
      # Don't use `#local_address` here because it should also use valid address if
      # the socket has been closed in between.
      UNIXSocket.new(client, @address)
    end
  end

  # Accepts an incoming connection and returns the client `UNIXSocket`.
  #
  # ```
  # require "socket/unix_server"
  #
  # UNIXServer.open("path/to_my_socket") do |server|
  #   loop do
  #     socket = server.accept
  #     # handle the client in a fiber
  #     spawn handle_connection(socket)
  #   end
  # end
  # ```
  #
  # Raises if the server is closed after invoking this method.
  def accept : UNIXSocket
    UNIXSocket.new @raw.accept, local_address
  end

  # Closes the socket, then deletes the filesystem pathname if it exists.
  def close
    @raw.close
  ensure
    path = @address.path
    File.delete(path) if File.exists?(path)
  end

  # Returns the `Socket::UNIXAddress` this server listens on, or `nil` if the socket is closed.
  def local_address? : Socket::UNIXAddress?
    @address unless closed?
  end

  # Returns the `Socket::UNIXAddress` this server listens on.
  #
  # Raises `Socket::Error` if the socket is closed.
  def local_address : Socket::UNIXAddress
    local_address? || raise Socket::Error.new("Unix socket not connected")
  end
end
