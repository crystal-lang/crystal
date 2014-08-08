class OpenSSL::SSL::Socket
  include IO

  def initialize(io, mode = :client, context = Context.default)
    @ssl = LibSSL.ssl_new(context)
    @bio = BIO.new(io)
    LibSSL.ssl_set_bio(@ssl, @bio, @bio)

    if mode == :client
      LibSSL.ssl_connect(@ssl)
    else
      LibSSL.ssl_accept(@ssl)
    end
  end

  def read(slice : Slice(UInt8), count)
    LibSSL.ssl_read(@ssl, slice.pointer(count), count)
  end

  def write(slice : Slice(UInt8), count)
    LibSSL.ssl_write(@ssl, slice.pointer(count), count)
  end

  def close
    while LibSSL.ssl_shutdown(@ssl) == 0; end
    LibSSL.ssl_free(@ssl)
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
