class OpenSSL::SSL::Socket
  include IO

  # If `sync_close` is true, closing this socket will
  # close the underlying IO.
  property? sync_close : Bool

  getter? closed : Bool

  def initialize(io, mode = :client, context = Context.default, @sync_close : Bool = false, hostname : String? = nil)
    @closed = false
    @ssl = LibSSL.ssl_new(context)
    unless @ssl
      raise OpenSSL::Error.new("SSL_new")
    end
    @bio = BIO.new(io)
    LibSSL.ssl_set_bio(@ssl, @bio, @bio)

    if mode == :client
      self.hostname = hostname if hostname
      ret = LibSSL.ssl_connect(@ssl)
      unless ret == 1
        raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_connect")
      end
    else
      raise ArgumentError.new("hostname has no meaning in server mode") if hostname
      ret = LibSSL.ssl_accept(@ssl)
      unless ret == 1
        raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_accept")
      end
    end
  end

  # Calling this for server or after connect has no effect
  private def hostname=(hostname : String)
    # Macro from OpenSSL: SSL_ctrl(s,SSL_CTRL_SET_TLSEXT_HOSTNAME,TLSEXT_NAMETYPE_host_name,(char *)name)
    LibSSL.ssl_ctrl(
      @ssl,
      LibSSL::SSLCtrl::SET_TLSEXT_HOSTNAME,
      LibSSL::TLSExt::NAMETYPE_host_name,
      hostname.to_unsafe.as(Pointer(Void))
    )
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
        begin
          ret = LibSSL.ssl_shutdown(@ssl)
          break if ret == 1
          raise OpenSSL::SSL::Error.new(@ssl, ret, "SSL_shutdown") if ret < 0
        rescue e : Errno
          case e.errno
          when 0
            # OpenSSL claimed an underlying syscall failed, but that didn't set any error state,
            # assume we're done
            break
          when Errno::EAGAIN
            # Ignore, shutdown did not complete yet
          else
            raise e
          end
        rescue e : OpenSSL::SSL::Error
          case e.error
          when .want_read?, .want_write?
            # Ignore, shutdown did not complete yet
          else
            raise e
          end
        end

        # ret == 0, retry, shutdown is not complete yet
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
