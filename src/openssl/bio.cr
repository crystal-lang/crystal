require "./lib_crypto"

# :nodoc:
struct OpenSSL::BIO
  CRYSTAL_BIO = begin
    biom = LibCrypto.BIO_meth_new(Int32::MAX, "Crystal BIO")

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

  @boxed_io : Void*

  def initialize(@io : IO)
    @bio = LibCrypto.BIO_new(CRYSTAL_BIO)

    # We need to store a reference to the box because it's
    # stored in `@bio.value.ptr`, but that lives in C-land,
    # not in Crystal-land.
    @boxed_io = Box(IO).box(io)

    LibCrypto.BIO_set_data(@bio, @boxed_io)
  end

  getter io

  def to_unsafe
    @bio
  end
end
