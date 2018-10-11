module Socket
  # :nodoc:
  macro delegate_close
    # Closes this socket.
    def close : Nil
      @raw.close
    end

    # Closes this socket for reading.
    def close_read : Nil
      @raw.close_read
    end

    # Closes this socket for writing.
    def close_write : Nil
      @raw.close_write
    end

    # Returns `true` if this socket is closed.
    def closed? : Bool
      @raw.closed?
    end
  end

  # :nodoc:
  macro delegate_io_methods
    Socket.delegate_sync

    # Returns the read timeout for this socket.
    def read_timeout : Time::Span?
      @raw.read_timeout
    end

    # Sets the read timeout for this socket.
    def read_timeout=(timeout : Time::Span | Number?)
      @raw.read_timeout = timeout
    end

    # Returns the write timeout for this socket.
    def write_timeout : Time::Span?
      @raw.write_timeout
    end

    # Sets the write timeout for this socket.
    def write_timeout=(timeout : Time::Span | Number?)
      @raw.write_timeout = timeout
    end

    def read(slice : Bytes) : Int32
      @raw.read(slice)
    end

    def write(slice : Bytes) : Nil
      @raw.write(slice)
    end
  end

  # :nodoc:
  macro delegate_tcp_options
    Socket.delegate_inet_methods

    def tcp_nodelay? : Bool
      @raw.tcp_nodelay?
    end

    def tcp_nodelay=(value : Bool) : Bool
      @raw.tcp_nodelay = value
    end

    def tcp_keepalive_idle : Int32
      @raw.tcp_keepalive_idle
    end

    def tcp_keepalive_idle=(value : Int32) : Int32
      @raw.tcp_keepalive_idle = value
    end

    def tcp_keepalive_count : Int32
      @raw.tcp_keepalive_count
    end

    def tcp_keepalive_count=(value : Int32) : Int32
      @raw.tcp_keepalive_count = value
    end

    def tcp_keepalive_interval : Int32
      @raw.tcp_keepalive_interval
    end

    def tcp_keepalive_interval=(value : Int32) : Int32
      @raw.tcp_keepalive_interval = value
    end
  end

  # :nodoc:
  macro delegate_sync
    def sync? : Bool
      @raw.sync?
    end

    def sync=(value : Bool) : Bool
      @raw.sync = value
    end
  end

  # :nodoc:
  macro delegate_inet_methods
    def keepalive? : Bool
      @raw.keepalive?
    end

    def keepalive=(value : Bool) : Bool
      @raw.keepalive = value
    end
  end

  # :nodoc:
  macro delegate_buffer_sizes
    # Returns the send buffer size for this socket.
    def send_buffer_size : Int32
      @raw.send_buffer_size
    end

    # Sets the send buffer size for this socket.
    def send_buffer_size=(value : Int32) : Int32
      @raw.send_buffer_size = value
    end

    # Returns the receive buffer size for this socket.
    def recv_buffer_size : Int32
      @raw.recv_buffer_size
    end

    # Sets the receive buffer size for this socket.
    def recv_buffer_size=(value : Int32) : Int32
      @raw.recv_buffer_size = value
    end
  end
end
