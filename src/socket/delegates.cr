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

    def flush
      @raw.flush
    end

    def peek
      @raw.peek
    end

    def read_buffering=(read_buffering)
      @raw.read_buffering
    end

    def read_buffering?
      @raw.read_buffering?
    end
  end

  # :nodoc:
  macro delegate_tcp_options
    Socket.delegate_inet_methods

    # Returns `true` if the Nable algorithm is disabled.
    def tcp_nodelay? : Bool
      @raw.getsockopt_bool LibC::TCP_NODELAY, level: Socket::Protocol::TCP
    end

    # Disable the Nagle algorithm when set to `true`, otherwise enables it.
    def tcp_nodelay=(value : Bool) : Bool
      @raw.setsockopt_bool LibC::TCP_NODELAY, value, level: Socket:: Protocol::TCP
    end

    {% unless flag?(:openbsd) %}
      # Returns the amount of time (in seconds) the connection must be idle before sending keepalive probes.
      def tcp_keepalive_idle : Int32
        optname = {% if flag?(:darwin) %}
          LibC::TCP_KEEPALIVE
        {% else %}
          LibC::TCP_KEEPIDLE
        {% end %}
        @raw.getsockopt optname, 0, level: Socket::Protocol::TCP
      end

      # Sets the amount of time (in seconds) the connection must be idle before sending keepalive probes.
      def tcp_keepalive_idle=(value : Int32) : Int32
        optname = {% if flag?(:darwin) %}
          LibC::TCP_KEEPALIVE
        {% else %}
          LibC::TCP_KEEPIDLE
        {% end %}
        @raw.setsockopt optname, value, level: Socket::Protocol::TCP
        value
      end

      # Returns the amount of time (in seconds) between keepalive probes.
      def tcp_keepalive_interval : Int32
        @raw.getsockopt LibC::TCP_KEEPINTVL, 0, level: Socket::Protocol::TCP
      end

      # Sets the amount of time (in seconds) between keepalive probes.
      def tcp_keepalive_interval=(value : Int32) : Int32
        @raw.setsockopt LibC::TCP_KEEPINTVL, value, level: Socket::Protocol::TCP
        value
      end

      # Returns the number of probes sent, without response before dropping the connection.
      def tcp_keepalive_count : Int32
        @raw.getsockopt LibC::TCP_KEEPCNT, 0, level: Socket::Protocol::TCP
      end

      # Sets the number of probes sent, without response before dropping the connection.
      def tcp_keepalive_count=(value : Int32) : Int32
        @raw.setsockopt LibC::TCP_KEEPCNT, value, level: Socket::Protocol::TCP
        value
      end
    {% end %}
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
      @raw.getsockopt_bool LibC::SO_KEEPALIVE
    end

    def keepalive=(value : Bool) : Bool
      @raw.setsockopt_bool LibC::SO_KEEPALIVE, value
    end
  end

  # :nodoc:
  macro delegate_buffer_sizes
    # Returns the send buffer size for this socket.
    def send_buffer_size : Int32
      @raw.getsockopt LibC::SO_SNDBUF, 0
    end

    # Sets the send buffer size for this socket.
    def send_buffer_size=(value : Int32) : Int32
      @raw.setsockopt LibC::SO_SNDBUF, value
      value
    end

    # Returns the receive buffer size for this socket.
    def recv_buffer_size : Int32
      @raw.getsockopt LibC::SO_RCVBUF, 0
    end

    # Sets the receive buffer size for this socket.
    def recv_buffer_size=(value : Int32) : Int32
      @raw.setsockopt LibC::SO_RCVBUF, value
      value
    end
  end
end
