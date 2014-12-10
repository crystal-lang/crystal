require "./lib_crypto"

struct OpenSSL::BIO

  CRYSTAL_BIO = begin
    crystal_bio = LibCrypto::BioMethod.new
    crystal_bio.name = "Crystal BIO".cstr

    crystal_bio.bwrite = -> (bio : LibCrypto::Bio*, data : UInt8*, len : Int32) do
      io = Box(IO).unbox(bio.value.ptr)
      io.write Slice.new(data, len)
      len
    end

    crystal_bio.bread = -> (bio : LibCrypto::Bio*, buffer : UInt8*, len : Int32) do
      io = Box(IO).unbox(bio.value.ptr)
      io.read(Slice.new(buffer, len)).to_i
    end

    crystal_bio.ctrl = -> (bio : LibCrypto::Bio*, cmd : Int32, num : Int64, ptr : Void*) do
      io = Box(IO).unbox(bio.value.ptr)

      case cmd
      when LibCrypto::CTRL_FLUSH
        io.flush if io.responds_to?(:flush); 1
      when LibCrypto::CTRL_PUSH, LibCrypto::CTRL_POP
        0
      else
        STDERR.puts "WARNING: Unsupported BIO ctrl call (#{cmd})"
        0
      end
    end

    crystal_bio.create = -> (bio : LibCrypto::Bio*) do
      bio.value.shutdown = 1
      bio.value.init = 1
      bio.value.num = -1
    end

    crystal_bio.destroy = -> (bio : LibCrypto::Bio*) { bio.value.ptr = Pointer(Void).null; 1 }

    crystal_bio
  end

  def initialize(io)
    @bio = LibCrypto.bio_new(pointerof(CRYSTAL_BIO))
    @bio.value.ptr = @boxed_io = Box(IO).box(io)
  end

  def to_unsafe
    @bio
  end
end
