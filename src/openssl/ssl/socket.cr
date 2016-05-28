class OpenSSL::SSL::Socket
  include IO

  # If `sync_close` is true, closing this socket will
  # close the underlying IO.
  property? sync_close : Bool

  getter? closed : Bool

  def initialize(io, mode = :client, context = Context.default, @sync_close : Bool = false)
    @closed = false
    @ssl = LibSSL.ssl_new(context)
    unless @ssl
      raise OpenSSL::Error.new("SSL_new")
    end
    @bio = BIO.new(io)
    LibSSL.ssl_set_bio(@ssl, @bio, @bio)

    if mode == :client
      ret = LibSSL.ssl_connect(@ssl)
      unless ret == 1
        raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_connect")
      end
    else
      ret = LibSSL.ssl_accept(@ssl)
      unless ret == 1
        raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_accept")
      end
    end

  end

  def finalize
    LibSSL.ssl_free(@ssl)
  end

  def read(slice : Slice(UInt8))
    check_open

    count = slice.size
    return 0 if count == 0
    LibSSL.ssl_read(@ssl, slice.pointer(count), count).tap do |bytes|
      unless bytes > 0
        raise OpenSSL::SSL::Error.new(@ssl, bytes, "SSL_read")
      end
    end
  end

  def write(slice : Slice(UInt8))
    check_open

    count = slice.size
    bytes = LibSSL.ssl_write(@ssl, slice.pointer(count), count)
    unless bytes > 0
      raise OpenSSL::SSL::Error.new(@ssl, bytes, "SSL_write")
    end
    nil
  end

  def flush
    @bio.io.flush
  end

  def close
    return if @closed
    @closed = true

    begin
      loop do
        ret = LibSSL.ssl_shutdown(@ssl)
        break if ret == 1
        raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_shutdown") if ret < 0
        # ret == 0, retry
      end
    rescue IO::Error
    ensure
      @bio.io.close if @sync_close
    end
  end

  def self.open_client(io, context = Context.default)
    ssl_sock = new(io, :client, context)
    begin
      yield ssl_sock
    ensure
      ssl_sock.close
    end
  end
end
