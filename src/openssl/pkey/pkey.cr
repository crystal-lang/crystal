require "../openssl"

module OpenSSL
  abstract class PKey
    class PKeyError < OpenSSL::Error; end

    def initialize(@pkey : LibCrypto::EVP_PKEY, @is_private = false)
      raise PKeyError.new "Invalid EVP_PKEY" unless @pkey
    end

    def initialize(is_private)
      initialize(LibCrypto.evp_pkey_new, is_private)
    end

    def to_unsafe
      @pkey
    end

    def finalize
      LibCrypto.evp_pkey_free(self)
    end

    def private_key?
      @is_private
    end

    def public_key?
      true
    end

    def sign(digest, data)
      unless private_key?
        raise PKeyError.new "Private key is needed"
      end
      data = data.to_slice
      LibCrypto.evp_digestinit_ex(digest, digest.to_unsafe_md, nil)
      LibCrypto.evp_digestupdate(digest, data, LibC::SizeT.new(data.bytesize))
      size = LibCrypto.evp_pkey_size(self)
      slice = Slice(UInt8).new(size)
      if LibCrypto.evp_signfinal(digest, slice, out len, self) == 0
        raise PKeyError.new "Unable to sign"
      end
      slice[0, len.to_i32]
    end

    def verify(digest, signature, data)
      data = data.to_slice
      signature = signature.to_slice
      LibCrypto.evp_digestinit_ex(digest, digest.to_unsafe_md, nil)
      LibCrypto.evp_digestupdate(digest, data, LibC::SizeT.new(data.bytesize))
      case LibCrypto.evp_verifyfinal(digest, signature, signature.size.to_u32, self)
      when 0
        false
      when 1
        true
      else
        raise PKeyError.new "Unable to verify"
      end
    end

    def to_pem
      io = MemoryIO.new
      to_pem(io)
      io.to_s
    end
  end
end
