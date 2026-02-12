require "./lib_crypto"

# :nodoc:
struct OpenSSL::BIO
  CRYSTAL_BIO = begin
    bio_id = LibCrypto.BIO_get_new_index
    raise OpenSSL::Error.new("BIO_get_new_index") if bio_id == -1

    bio_type = bio_id | LibCrypto::BIO_TYPE_SOURCE_SINK | LibCrypto::BIO_TYPE_DESCRIPTOR
    biom = LibCrypto.BIO_meth_new(bio_type, "Crystal BIO")
    raise OpenSSL::Error.new("BIO_meth_new") if biom.null?

    {% if LibCrypto.has_method?(:BIO_meth_set_read_ex) %}
      LibCrypto.BIO_meth_set_read_ex(biom, ->read_ex)
    {% else %}
      LibCrypto.BIO_meth_set_read(biom, ->read)
    {% end %}

    {% if LibCrypto.has_method?(:BIO_meth_set_write_ex) %}
      LibCrypto.BIO_meth_set_write_ex(biom, ->write_ex)
    {% else %}
      LibCrypto.BIO_meth_set_write(biom, ->write)
    {% end %}

    LibCrypto.BIO_meth_set_ctrl(biom, ->ctrl)
    LibCrypto.BIO_meth_set_create(biom, ->create)
    LibCrypto.BIO_meth_set_destroy(biom, ->destroy)

    biom
  end

  def self.write_ex(bio, data, len, writep)
    count = len > Int32::MAX ? Int32::MAX : len.to_i
    io = Box(IO).unbox(LibCrypto.BIO_get_data(bio))
    io.write Slice.new(data, count)
    writep.value = LibC::SizeT.new(count)
    1
  end

  def self.write(bio, data, len)
    io = Box(IO).unbox(LibCrypto.BIO_get_data(bio))
    io.write Slice.new(data, len)
    len
  end

  def self.read_ex(bio, buffer, len, readp)
    count = len > Int32::MAX ? Int32::MAX : len.to_i
    io = Box(IO).unbox(LibCrypto.BIO_get_data(bio))
    ret = io.read Slice.new(buffer, count)
    readp.value = LibC::SizeT.new(ret)
    1
  end

  def self.read(bio, buffer, len)
    io = Box(IO).unbox(LibCrypto.BIO_get_data(bio))
    io.read(Slice.new(buffer, len)).to_i
  end

  def self.ctrl(bio, cmd, num, ptr)
    io = Box(IO).unbox(LibCrypto.BIO_get_data(bio))
    val = case cmd
          when LibCrypto::CTRL_FLUSH
            io.flush
            1
          when LibCrypto::CTRL_PUSH, LibCrypto::CTRL_POP, LibCrypto::CTRL_EOF
            0
          when LibCrypto::CTRL_SET_KTLS_SEND
            0
          when LibCrypto::CTRL_GET_KTLS_SEND, LibCrypto::CTRL_GET_KTLS_RECV
            0
          when LibCrypto::BIO_C_GET_FD
            if io.is_a?(Socket) || io.is_a?(IO::FileDescriptor)
              io.fd
            else
              -1
            end
          else
            STDERR.puts "WARNING: Unsupported BIO ctrl call (#{cmd})"
            0
          end
    LibCrypto::Long.new(val)
  end

  def self.create(bio)
    LibCrypto.BIO_set_shutdown(bio, 1)
    LibCrypto.BIO_set_init(bio, 1)
    1
  end

  def self.destroy(bio)
    LibCrypto.BIO_set_data(bio, Pointer(Void).null)
    1
  end

  def initialize(@io : IO)
    if io.is_a?(IO::Buffered)
      # Disable buffers of the underlying IO (e.g. TCP socket) so OpenSSL
      # becomes responsible of what needs to be read/written on the wire;
      # instead, buffers shall be on OpenSSL::SSL::Socket (for example).
      io.sync = true
      io.read_buffering = false
    end

    @bio = LibCrypto.BIO_new(CRYSTAL_BIO)
    raise OpenSSL::Error.new("BIO_new") if @bio.null?

    LibCrypto.BIO_set_data(@bio, Box(IO).box(io))
  end

  getter io

  def to_unsafe
    @bio
  end
end
