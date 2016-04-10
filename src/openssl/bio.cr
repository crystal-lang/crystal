require "./lib_crypto"

# :nodoc:
struct OpenSSL::BIO
  CRYSTAL_BIO = begin
    crystal_bio = LibCrypto::BioMethod.new
    crystal_bio.name = "Crystal BIO".to_unsafe

    crystal_bio.bwrite = LibCrypto::BioMethodWrite.new do |bio, data, len|
      io = Box(IO).unbox(bio.value.ptr)
      io.write Slice.new(data, len)
      len
    end

    crystal_bio.bread = LibCrypto::BioMethodRead.new do |bio, buffer, len|
      io = Box(IO).unbox(bio.value.ptr)
      io.flush
      io.read(Slice.new(buffer, len)).to_i
    end

    crystal_bio.ctrl = LibCrypto::BioMethodCtrl.new do |bio, cmd, num, ptr|
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

    crystal_bio.create = LibCrypto::BioMethodCreate.new do |bio|
      bio.value.shutdown = 1
      bio.value.init = 1
      bio.value.num = -1
    end

    crystal_bio.destroy = LibCrypto::BioMethodDestroy.new do |bio|
      bio.value.ptr = Pointer(Void).null
      1
    end

    crystal_bio
  end

  @boxed_io : Void*

  def initialize(@io : IO)
    @bio = LibCrypto.bio_new(pointerof(CRYSTAL_BIO))

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
