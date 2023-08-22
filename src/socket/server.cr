class Socket
  module Server
    # Accepts an incoming connection and returns the client socket.
    #
    # ```
    # require "socket"
    #
    # server = TCPServer.new(2202)
    # while true
    #   socket = server.accept
    #   socket.puts Time.utc
    #   socket.close
    # end
    # ```
    #
    # If the server is closed after invoking this method, an `IO::Error` (closed stream) exception must be raised.
    abstract def accept : IO

    # Accepts an incoming connection and returns the client socket.
    #
    # Returns `nil` if the server is closed after invoking this method.
    #
    # ```
    # require "socket"
    #
    # server = TCPServer.new(2202)
    # while socket = server.accept?
    #   socket.puts Time.utc
    #   socket.close
    # end
    # ```
    abstract def accept? : IO?

    # Accepts an incoming connection and yields the client socket to the block.
    # Eventually closes the connection when the block returns.
    #
    # Returns the value of the block. If the server is closed after invoking this
    # method, an `IO::Error` (closed stream) exception will be raised.
    #
    # ```
    # require "socket"
    #
    # server = TCPServer.new(2202)
    # server.accept do |socket|
    #   socket.puts Time.utc
    # end
    # ```
    def accept(&)
      sock = accept
      begin
        yield sock
      ensure
        sock.close
      end
    end

    # Accepts an incoming connection and yields the client socket to the block.
    # Eventually closes the connection when the block returns.
    #
    # Returns the value of the block or `nil` if the server is closed after
    # invoking this method.
    #
    # ```
    # require "socket"
    #
    # server = UNIXServer.new("/tmp/service.sock")
    # server.accept? do |socket|
    #   socket.puts Time.utc
    # end
    # ```
    def accept?(&)
      sock = accept?
      return unless sock

      begin
        yield sock
      ensure
        sock.close
      end
    end
  end
end
