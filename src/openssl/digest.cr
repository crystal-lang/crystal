require "./lib_crypto"
require "./error"
require "digest/digest"

module OpenSSL
  class Digest < ::Digest
    class Error < OpenSSL::Error; end

    class UnsupportedError < Error; end

    getter name : String
    @ctx : LibCrypto::EVP_MD_CTX

    def initialize(@name : String)
      @ctx = new_evp_mt_ctx(name)
    end

    protected def initialize(@name : String, @ctx : LibCrypto::EVP_MD_CTX)
    end

    private def new_evp_mt_ctx(name)
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
      raise Error.new("Invalid EVP_MD_CTX") unless ctx
      ctx
    end

    def finalize
      LibCrypto.evp_md_ctx_free(self)
    end

    def dup
      Digest.new(@name, dup_ctx)
    end

    protected def dup_ctx
      ctx = LibCrypto.evp_md_ctx_new
      if LibCrypto.evp_md_ctx_copy(ctx, @ctx) == 0
        LibCrypto.evp_md_ctx_free(ctx)
        raise Error.new("Unable to dup digest")
      end
      ctx
    end

    private def reset_impl : Nil
      if LibCrypto.evp_digestinit_ex(self, to_unsafe_md, nil) != 1
        raise Error.new "Digest initialization failed."
      end
    end

    private def update_impl(data : Bytes) : Nil
      check_finished
      if LibCrypto.evp_digestupdate(self, data, data.bytesize) != 1
        raise Error.new "EVP_DigestUpdate"
      end
    end

    private def final_impl(dst : Bytes) : Nil
      unless dst.bytesize == digest_size
        raise ArgumentError.new("Incorrect data size: #{dst.bytesize}, expected: #{digest_size}")
      end
      if LibCrypto.evp_digestfinal_ex(@ctx, dst, nil) != 1
        raise Error.new "EVP_DigestFinal_ex"
      end
    end

    def digest_size : Int32
      LibCrypto.evp_md_size(to_unsafe_md).to_i
    end

    def block_size : Int32
      LibCrypto.evp_md_block_size(to_unsafe_md).to_i
    end

    def to_unsafe_md
      LibCrypto.evp_md_ctx_md(self)
    end

    def to_unsafe
      @ctx
    end
  end
end
