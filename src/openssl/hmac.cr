require "./lib_crypto"
require "./digest/digest_base"

class OpenSSL::HMAC
  def self.digest(algorithm : Symbol, key, data)
    evp = fetch_evp(algorithm)
    key_slice = key.to_slice
    data_slice = data.to_slice
    buffer = Slice(UInt8).new(128)

    LibCrypto.hmac(evp, key_slice, key_slice.size, data_slice, data_slice.size, buffer, out buffer_len)
    buffer[0, buffer_len.to_i]
  end

  def self.hexdigest(algorithm : Symbol, key, data)
    digest(algorithm, key, data).hexstring
  end

  Error = Class.new(OpenSSL::Error)

  include DigestBase

  def initialize
    @ctx = LibCrypto::HMAC_CTX_Struct.new
    LibCrypto.hmac_ctx_init(self)
  end

  def finalize
    LibCrypto.hmac_ctx_cleanup(self)
  end

  def self.new(algorithm : Symbol, key)
    evp = fetch_evp(algorithm)

    new.tap do |hmac|
      LibCrypto.hmac_init_ex(hmac, key.to_unsafe as Pointer(Void), key.bytesize, evp, nil)
    end
  end

  def clone
    HMAC.new.tap do |hmac|
      LibCrypto.hmac_ctx_copy(hmac, self)
    end
  end

  def reset
    LibCrypto.hmac_init(self, nil, 0, nil)
    self
  end

  def update(data)
    LibCrypto.hmac_update(self, data, LibC::SizeT.new(data.bytesize))
    self
  end

  protected def self.fetch_evp(algorithm : Symbol)
    case algorithm
    when :dss       then LibCrypto.evp_dss
    when :dss1      then LibCrypto.evp_dss1
    when :md4       then LibCrypto.evp_md4
    when :md5       then LibCrypto.evp_md5
    when :ripemd160 then LibCrypto.evp_ripemd160
    when :sha       then LibCrypto.evp_sha
    when :sha1      then LibCrypto.evp_sha1
    when :sha224    then LibCrypto.evp_sha224
    when :sha256    then LibCrypto.evp_sha256
    when :sha384    then LibCrypto.evp_sha384
    when :sha512    then LibCrypto.evp_sha512
    else                 raise "Unsupported digest algorithm: #{algorithm}"
    end
  end

  protected def finish
    size = LibCrypto.evp_md_size(@ctx.md)
    data = Slice(UInt8).new(size)
    LibCrypto.hmac_final(self, data, out len)
    data[0, len.to_i32]
  end

  def to_unsafe
    pointerof(@ctx)
  end
end
