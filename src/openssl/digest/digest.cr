require "../lib_crypto"
require "digest/base"
require "./digest_base"

module OpenSSL
  class Digest < ::Digest::Base
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

    def dup
      ctx = LibCrypto.evp_md_ctx_new
      if LibCrypto.evp_md_ctx_copy(ctx, @ctx) == 0
        LibCrypto.evp_md_ctx_free(ctx)
        raise Error.new("Unable to dup digest")
      end
      Digest.new(@name, ctx)
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

    private def final_impl(data : Bytes) : Nil
      raise ArgumentError.new("data size incorrect") unless data.bytesize == digest_size
      if LibCrypto.evp_digestfinal_ex(@ctx, data, nil) != 1
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
