require "./lib_crypto"
require "./ktls"

# :nodoc:
class OpenSSL::BIO
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

  def self.read_ex(b, buffer, len, readp)
    size = len > Int32::MAX ? Int32::MAX : len.to_i
    bio = Box(BIO).unbox(LibCrypto.BIO_get_data(b))

    {% if OpenSSL.has_constant?(:KTLS) %}
      if bio.ktls_recv?
        case ret = KTLS.read_record(bio.socket, buffer, size)
        in Int32
          readp.value = LibC::SizeT.new(ret)
          return 1
        in Errno
          readp.value = LibC::SizeT.new(0)
          return ret.value
        end
      end
    {% end %}

    ret = bio.io.read(Slice.new(buffer, size))
    readp.value = LibC::SizeT.new(ret)
    1
  end

  def self.read(b, buffer, len)
    bio = Box(BIO).unbox(LibCrypto.BIO_get_data(b))
    bio.io.read(Slice.new(buffer, len)).to_i
  end

  def self.write_ex(b, data, len, writep)
    size = len > Int32::MAX ? Int32::MAX : len.to_i
    bio = Box(BIO).unbox(LibCrypto.BIO_get_data(b))

    {% if OpenSSL.has_constant?(:KTLS) %}
      if bio.ktls_send_ctrl_msg?
        case ret = KTLS.send_ctrl_message(bio.socket, bio.ktls_record_type, data, size)
        in Int32
          LibCrypto.BIO_clear_flags(b, LibCrypto::BIO_FLAGS_KTLS_TX_CTRL_MSG)
          writep.value = LibC::SizeT.new(ret)
          return 1
        in Errno
          writep.value = LibC::SizeT.new(0)
          return ret.value
        end
      end
    {% end %}

    bio.io.write Slice.new(data, size)
    writep.value = LibC::SizeT.new(size)
    1
  end

  def self.write(b, data, len)
    bio = Box(BIO).unbox(LibCrypto.BIO_get_data(b))
    bio.io.write Slice.new(data, len)
    len
  end

  def self.ctrl(b, cmd, num, ptr)
    bio = Box(BIO).unbox(LibCrypto.BIO_get_data(b))
    val = {% begin %}
            case cmd
            when LibCrypto::CTRL_FLUSH
              bio.io.flush
              1
            when LibCrypto::CTRL_PUSH, LibCrypto::CTRL_POP, LibCrypto::CTRL_EOF
              0
            {% if OpenSSL.has_constant?(:KTLS) %}
              when LibCrypto::CTRL_SET_KTLS
                socket = bio.socket
                is_tx = num != 0
                if KTLS.enable(socket) && KTLS.start(socket, ptr, is_tx)
                  LibCrypto.BIO_set_flags(b, is_tx ? LibCrypto::BIO_FLAGS_KTLS_TX : LibCrypto::BIO_FLAGS_KTLS_RX)
                  1
                else
                  0
                end
              when LibCrypto::CTRL_GET_KTLS_SEND
                bio.ktls_send? ? 1 : 0
              when LibCrypto::CTRL_GET_KTLS_RECV
                bio.ktls_recv? ? 1 : 0
              when LibCrypto::CTRL_SET_KTLS_TX_SEND_CTRL_MSG
                LibCrypto.BIO_set_flags(b, LibCrypto::BIO_FLAGS_KTLS_TX_CTRL_MSG)
                bio.ktls_record_type = num.to_u8
                0
              when LibCrypto::CTRL_CLEAR_KTLS_TX_CTRL_MSG
                LibCrypto.BIO_clear_flags(b, LibCrypto::BIO_FLAGS_KTLS_TX_CTRL_MSG)
                0
              when LibCrypto::CTRL_SET_KTLS_TX_ZEROCOPY_SENDFILE
                ret = KTLS.enable_tx_zerocopy_sendfile(bio.socket)
                LibCrypto.BIO_set_flags(b, LibCrypto::BIO_FLAGS_KTLS_TX_ZEROCOPY_SENDFILE) if ret
                ret ? 1 : 0
            {% else %}
              when LibCrypto::CTRL_SET_KTLS,
                   LibCrypto::CTRL_GET_KTLS_SEND,
                   LibCrypto::CTRL_GET_KTLS_RECV,
                   LibCrypto::CTRL_SET_KTLS_TX_ZEROCOPY_SENDFILE
                0
            {% end %}
            when LibCrypto::BIO_C_GET_FD
              io = bio.io
              if io.is_a?(Socket) || io.is_a?(IO::FileDescriptor)
                io.fd
              else
                -1
              end
            else
              STDERR.puts "WARNING: Unsupported BIO ctrl call (#{cmd})"
              0
            end
          {% end %}
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
    @bio = LibCrypto.BIO_new(CRYSTAL_BIO)
    raise OpenSSL::Error.new("BIO_new") if @bio.null?

    LibCrypto.BIO_set_data(@bio, self.as(Void*))
  end

  getter io : IO

  def socket
    @io.as(Socket)
  end

  {% if OpenSSL.has_constant?(:KTLS) %}
    property ktls_record_type : UInt8 = 0
  {% end %}

  def ktls_send?
    @io.is_a?(Socket) && flag?(LibCrypto::BIO_FLAGS_KTLS_TX)
  end

  def ktls_send_ctrl_msg?
    @io.is_a?(Socket) && flag?(LibCrypto::BIO_FLAGS_KTLS_TX_CTRL_MSG)
  end

  def ktls_recv?
    @io.is_a?(Socket) && flag?(LibCrypto::BIO_FLAGS_KTLS_RX)
  end

  private def flag?(flag)
    (LibCrypto.BIO_test_flags(@bio, flag) & flag) == flag
  end

  def to_unsafe
    @bio
  end
end
