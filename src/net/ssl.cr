lib LibBIO("crypto")
  struct Bio
    method : Void*
    callback : (Void*, Int32, UInt8*, Int32, Int64, Int64) -> Int64
    cb_arg : UInt8*
    init : Int32
    shutdown : Int32
    flags : Int32
    retry_reason : Int32
    num : Int32
    ptr : Void*
    next_bio : Void*
    prev_bio : Void*
    references : Int32
    num_read : UInt64
    num_write : UInt64
  end

  CTRL_PUSH = 6
  CTRL_POP = 7
  CTRL_FLUSH = 11

  struct BioMethod
    type_id : Int32
    name : UInt8*
    bwrite : (Bio*, UInt8*, Int32) -> Int32
    bread : (Bio*, UInt8*, Int32) -> Int32
    bputs : (Bio*, UInt8*) -> Int32
    bgets : (Bio*, UInt8*, Int32) -> Int32
    ctrl : (Bio*, Int32, Int64, Void*) -> Int32
    create : Bio* -> Int32
    destroy : Bio* -> Int32
    callback_ctrl : (Bio*, Int32, Void*) -> Int64
  end

  fun bio_new = BIO_new(method : BioMethod*) : Bio*
  fun bio_free = BIO_free(bio : Bio*) : Int32
end

lib OpenSSL("ssl")
  type SSLMethod : Void*
  type SSLContext : Void*
  type SSL : Void*

  enum SSLFileType
    PEM = 1
    ASN1 = 2
  end

  fun ssl_load_error_strings = SSL_load_error_strings()
  fun ssl_library_init = SSL_library_init()
  fun sslv23_method  = SSLv23_method() : SSLMethod
  fun ssl_ctx_new = SSL_CTX_new(method : SSLMethod) : SSLContext
  fun ssl_ctx_free = SSL_CTX_free(context : SSLContext)
  fun ssl_new = SSL_new(context : SSLContext) : SSL
  fun ssl_connect = SSL_connect(handle : SSL) : Int32
  fun ssl_accept = SSL_accept(handle : SSL) : Int32
  fun ssl_write = SSL_write(handle : SSL, text : UInt8*, length : Int32) : Int32
  fun ssl_read = SSL_read(handle : SSL, buffer : UInt8*, read_size : Int32) : Int32
  fun ssl_shutdown = SSL_shutdown(handle : SSL) : Int32
  fun ssl_free = SSL_free(handle : SSL)
  fun ssl_ctx_use_certificate_chain_file = SSL_CTX_use_certificate_chain_file(ctx : SSLContext, file : UInt8*) : Int32
  fun ssl_ctx_use_privatekey_file = SSL_CTX_use_PrivateKey_file(ctx : SSLContext, file : UInt8*, filetype : SSLFileType) : Int32
  fun ssl_set_bio = SSL_set_bio(handle : SSL, rbio : LibBIO::Bio*, wbio : LibBIO::Bio*)
end

class SSLContext
  OpenSSL.ssl_load_error_strings
  OpenSSL.ssl_library_init

  getter handle

  def self.default
    @@default ||= SSLContext.new
  end

  CRYSTAL_BIO = begin
    crystal_bio = LibBIO::BioMethod.new
    crystal_bio.name = "Crystal BIO".cstr

    crystal_bio.bwrite = -> (bio : LibBIO::Bio*, data : UInt8*, len : Int32) do
      io = Box(IO).unbox(bio.value.ptr)
      io.write(data, len)
      len
    end

    crystal_bio.bread = -> (bio : LibBIO::Bio*, buffer : UInt8*, len : Int32) do
      io = Box(IO).unbox(bio.value.ptr)
      io.read(buffer, len).to_i
    end

    crystal_bio.ctrl = -> (bio : LibBIO::Bio*, cmd : Int32, num : Int64, ptr : Void*) do
      io = Box(IO).unbox(bio.value.ptr)

      case cmd
      when LibBIO::CTRL_FLUSH
        io.flush if io.responds_to?(:flush); 1
      when LibBIO::CTRL_PUSH, LibBIO::CTRL_POP
        0
      else
        STDERR.puts "WARNING: Unsupported BIO ctrl call (#{cmd})"
        0
      end
    end

    crystal_bio.create = -> (bio : LibBIO::Bio*) do
      bio.value.shutdown = 1
      bio.value.init = 1
      bio.value.num = -1
    end

    crystal_bio.destroy = -> (bio : LibBIO::Bio*) { bio.value.ptr = Pointer(Void).null; 1 }

    crystal_bio
  end

  def initialize
    @handle = OpenSSL.ssl_ctx_new(OpenSSL.sslv23_method)
  end

  def finalize
    OpenSSL.ssl_ctx_free(@handle)
  end

  def certificate_chain=(file_path)
    OpenSSL.ssl_ctx_use_certificate_chain_file(@handle, file_path)
  end

  def private_key=(file_path)
    OpenSSL.ssl_ctx_use_privatekey_file(@handle, file_path, OpenSSL::SSLFileType::PEM)
  end

  def new_client(io)
    boxed_io, ssl = create_bio_and_ssl(io)

    OpenSSL.ssl_connect(ssl)
    SSLSocket.new(ssl, boxed_io)
  end

  def new_server(io)
    boxed_io, ssl = create_bio_and_ssl(io)

    OpenSSL.ssl_accept(ssl)
    SSLSocket.new(ssl, boxed_io)
  end

  # private

  def create_bio_and_ssl(io)
    bio = LibBIO.bio_new(pointerof(CRYSTAL_BIO))
    bio.value.ptr = boxed_io = Box(IO).box(io)

    ssl = OpenSSL.ssl_new(@handle)
    OpenSSL.ssl_set_bio(ssl, bio, bio)

    {boxed_io, ssl}
  end
end

class SSLSocket
  include IO

  def initialize(@ssl, @boxed_io)
  end

  def read(buffer : UInt8*, count)
    OpenSSL.ssl_read(@ssl, buffer, count)
  end

  def write(buffer : UInt8*, count)
    OpenSSL.ssl_write(@ssl, buffer, count)
  end

  def close
    while OpenSSL.ssl_shutdown(@ssl) == 0; end
    OpenSSL.ssl_free(@ssl)
  end

  def self.open_client(sock, context = SSLContext.default)
    ssl_sock = context.new_client(sock)
    begin
      yield ssl_sock
    ensure
      ssl_sock.close
    end
  end
end
