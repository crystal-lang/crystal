require "./lib_crypto"

# :nodoc:
struct OpenSSL::BIO
  CRYSTAL_BIO = begin
    bwrite = LibCrypto::BioMethodWriteOld.new do |bio, data, len|
      io = Box(IO).unbox(bio.value.ptr)
      io.write Slice.new(data, len)
      len
    end

    bread = LibCrypto::BioMethodReadOld.new do |bio, buffer, len|
      io = Box(IO).unbox(bio.value.ptr)
      io.flush
      io.read(Slice.new(buffer, len)).to_i
    end

    ctrl = LibCrypto::BioMethodCtrl.new do |bio, cmd, num, ptr|
      io = Box(IO).unbox(bio.value.ptr)

      val = case cmd
            when LibCrypto::CTRL_FLUSH
              io.flush
              1
            when LibCrypto::CTRL_PUSH, LibCrypto::CTRL_POP
              0
            else
              STDERR.puts "WARNING: Unsupported BIO ctrl call (#{cmd})"
              0
            end
      LibCrypto::Long.new(val)
    end

    create = LibCrypto::BioMethodCreate.new do |bio|
      bio.value.shutdown = 1
      bio.value.init = 1
      bio.value.num = -1
    end

    destroy = LibCrypto::BioMethodDestroy.new do |bio|
      bio.value.ptr = Pointer(Void).null
      1
    end

    {% if LibCrypto::OPENSSL_110 %}
      biom = LibCrypto.BIO_meth_new(Int32::MAX, "Crystal BIO")
      LibCrypto.BIO_meth_set_write(biom, bwrite)
      LibCrypto.BIO_meth_set_read(biom, bread)
      LibCrypto.BIO_meth_set_ctrl(biom, ctrl)
      LibCrypto.BIO_meth_set_create(biom, create)
      LibCrypto.BIO_meth_set_destroy(biom, destroy)
      biom
    {% else %}
      biom = Pointer(LibCrypto::BioMethod).malloc(1)
      biom.value.type_id = Int32::MAX
      biom.value.name = "Crystal BIO"
      biom.value.bwrite = bwrite
      biom.value.bread = bread
      biom.value.ctrl = ctrl
      biom.value.create = create
      biom.value.destroy = destroy
      biom
    {% end %}
  end

  @boxed_io : Void*
  @bio : LibCrypto::Bio*

  def initialize(@io : IO)
    @bio = LibCrypto.bio_new(CRYSTAL_BIO)

    # We need to store a reference to the box because it's
    # stored in `@bio.value.ptr`, but that lives in C-land,
    # not in Crystal-land.
    @boxed_io = Box(IO).box(io)

    @bio.value.ptr = @boxed_io
  end

  getter io

  def to_unsafe
    @bio
  end
end
