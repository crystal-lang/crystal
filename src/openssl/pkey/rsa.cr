require "../lib_crypto"

module OpenSSL
  class PKey::RSA < PKey
    class RSAError < PKeyError; end

    def self.new(pem : String, password = nil)
      self.new(MemoryIO.new(io), password)
    end

    def self.new(io : IO, password = nil)
      bio = MemBIO.new
      IO.copy(io, bio)
      # FIXME: password callback
      new(LibCrypto.pem_read_bio_privatekey(bio, nil, nil, nil), true)
    end

    def self.new(size : Int32)
      self.generate(size)
    end

    def self.generate(size)
      rsa = LibCrypto.rsa_generate_key(size, 65537.to_u32, nil, nil)
      new(true).tap do |pkey|
        LibCrypto.evp_pkey_assign(pkey, LibCrypto::NID_rsaEncryption, rsa as Pointer(Void))
      end
    end

    def public_key
      pub_rsa = LibCrypto.rsapublickey_dup(rsa)
      RSA.new(false).tap do |pkey|
        LibCrypto.evp_pkey_assign(pkey, LibCrypto::NID_rsaEncryption, pub_rsa as Pointer(Void))
      end
    end

    private def max_encrypt_size
      LibCrypto.rsa_size(rsa)
    end

    private def rsa
      LibCrypto.evp_pkey_get1_rsa(self)
    end

    def public_encrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      from = data.to_slice
      if max_encrypt_size < from.size
        raise RSAError.new "value is too big to be encrypted"
      end
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_public_encrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RSAError.new "unable to encrypt"
      end
      to[0, len]
    end

    def public_decrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      from = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_public_decrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RSAError.new "unable to decrypt"
      end
      to[0, len]
    end

    def private_encrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      unless private_key?
        raise RSAError.new "private key needed"
      end
      from = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_private_encrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RSAError.new "unable to encrypt"
      end
      to[0, len]
    end

    def private_decrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      unless private_key?
        raise RSAError.new "private key needed"
      end
      from = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_private_decrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RSAError.new "unable to decrypt"
      end
      to[0, len]
    end

    def to_pem(io)
      bio = MemBIO.new
      if private_key?
        LibCrypto.pem_write_bio_rsaprivatekey(bio, rsa, nil, nil, 0, nil, nil)
      else
        LibCrypto.pem_write_bio_rsa_pubkey(bio, rsa)
      end
      IO.copy(bio, io)
    end

    def to_text
      bio = MemBIO.new
      LibCrypto.rsa_print(bio, rsa, 0)
      bio.to_string
    end

    def to_der
      fn = ->(buf : UInt8** | Nil) {
        if private_key?
          LibCrypto.i2d_rsaprivatekey(rsa, buf)
        else
          LibCrypto.i2d_rsa_pubkey(rsa, buf)
        end
      }
      len = fn.call(nil)
      if len <= 0
        raise RSAError.new
      end
      slice = Slice(UInt8).new(len)
      p = slice.to_unsafe
      len = fn.call(pointerof(p))
      slice[0, len]
    end
  end
end
