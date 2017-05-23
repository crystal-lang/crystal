require "../lib_crypto"
require "./digest_base"

module OpenSSL
  class Digest
    class Error < OpenSSL::Error; end

    class UnsupportedError < Error; end

    include DigestBase

    getter name : String

    def initialize(@name, @ctx : LibCrypto::EVP_MD_CTX)
      raise Error.new("Invalid EVP_MD_CTX") unless @ctx
    end

    protected def self.new_evp_mt_ctx(name)
      md = LibCrypto.evp_get_digestbyname(name)
      unless md
        raise UnsupportedError.new("Unsupported digest algorithm: #{name}")
      end
      ctx = LibCrypto.evp_md_ctx_new
      unless ctx
        raise Error.new "Digest initialization failed."
      end
      if LibCrypto.evp_digestinit_ex(ctx, md, nil) != 1
        raise Error.new "Digest initialization failed."
      end
      ctx
    end

    def self.new(name)
      new(name, new_evp_mt_ctx(name))
    end

    def finalize
      LibCrypto.evp_md_ctx_free(self)
    end

    def clone
      ctx = LibCrypto.evp_md_ctx_new
      if LibCrypto.evp_md_ctx_copy(ctx, @ctx) == 0
        LibCrypto.evp_md_ctx_free(ctx)
        raise Error.new("Unable to clone digest")
      end
      Digest.new(@name, ctx)
    end

    def reset
      if LibCrypto.evp_digestinit_ex(self, to_unsafe_md, nil) != 1
        raise Error.new "Digest initialization failed."
      end
      self
    end

    def update(data : String | Slice)
      LibCrypto.evp_digestupdate(self, data, data.size)
      self
    end

    protected def finish
      size = digest_size
      data = Pointer(UInt8).malloc(size)
      LibCrypto.evp_digestfinal_ex(@ctx, data, nil)
      data.to_slice(size)
    end

    def digest_size
      LibCrypto.evp_md_size(to_unsafe_md)
    end

    def block_size
      LibCrypto.evp_md_block_size(to_unsafe_md)
    end

    def to_unsafe_md
      LibCrypto.evp_md_ctx_md(self)
    end

    def to_unsafe
      @ctx
    end
  end
end
