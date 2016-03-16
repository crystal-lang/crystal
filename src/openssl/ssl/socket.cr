class OpenSSL::SSL::Socket
  include IO

  @ssl : LibSSL::SSL
  @bio : OpenSSL::BIO

  # If `sync_close` is true, closing this socket will
  # close the underlying IO.
  property? sync_close : Bool

  getter? closed : Bool

  def initialize(io, mode = :client, context = Context.default, @sync_close : Bool = false)
    @closed = false
    @ssl = LibSSL.ssl_new(context)
    @bio = BIO.new(io)
    LibSSL.ssl_set_bio(@ssl, @bio, @bio)

    if mode == :client
      LibSSL.ssl_connect(@ssl)
    else
      LibSSL.ssl_accept(@ssl)
    end
  end

  def finalize
    LibSSL.ssl_free(@ssl)
  end

  def read(slice : Slice(UInt8))
    count = slice.size
    return 0 if count == 0
    LibSSL.ssl_read(@ssl, slice.pointer(count), count)
  end

  def write(slice : Slice(UInt8))
    count = slice.size
    LibSSL.ssl_write(@ssl, slice.pointer(count), count)
    nil
  end

  def flush
    @bio.io.flush
  end

  def close
    return if @closed
    @closed = true

    begin
      while LibSSL.ssl_shutdown(@ssl) == 0; end
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
