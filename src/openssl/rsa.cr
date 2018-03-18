require "big"
require "./pkey"

module OpenSSL
  class RSA < PKey
    class RsaError < PKeyError; end

    @blinding_on : Bool = false

    def self.generate(size : Int32, exponent : UInt32)
      rsa_pointer = LibCrypto.rsa_new

      exponent_bn = LibCrypto.bignum_new
      LibCrypto.set_bignum_from_decimal(pointerof(exponent_bn), exponent.to_s)
      LibCrypto.rsa_generate_key_ex(rsa_pointer, size, exponent_bn, nil)

      new(true).tap do |pkey|
        LibCrypto.evp_pkey_set1_rsa(pkey, rsa_pointer)
      end
    end

    private def rsa
      LibCrypto.evp_pkey_get1_rsa(self)
    end

    def public_key
      pub_rsa = LibCrypto.rsa_public_key_dup(rsa)
      raise RsaError.new "Could not get public key from RSA" unless pub_rsa

      RSA.new(false).tap do |pkey|
        LibCrypto.evp_pkey_set1_rsa(pkey, pub_rsa)
      end
    end

    def public_encrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      from = data.to_slice
      if max_encrypt_size < from.size
        raise RsaError.new "value is too big to be encrypted"
      end
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_public_encrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RsaError.new "unable to encrypt"
      end
      to[0, len]
    end

    def public_decrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      from = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_public_decrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RsaError.new "unable to decrypt"
      end
      to[0, len]
    end

    def private_encrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      unless private?
        raise RsaError.new "private key needed"
      end
      from = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_private_encrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RsaError.new "unable to encrypt"
      end
      to[0, len]
    end

    def private_decrypt(data, padding = LibCrypto::Padding::PKCS1_PADDING)
      unless private?
        raise RsaError.new "private key needed"
      end
      from = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      len = LibCrypto.rsa_private_decrypt(from.size, from, to, rsa, padding)
      if len < 0
        raise RsaError.new "unable to decrypt"
      end
      to[0, len]
    end

    def blinding_on?
      @blinding_on
    end

    def blinding_on!
      @blinding_on = (LibCrypto.rsa_blinding_on(rsa, nil) == 1)
    end

    def blinding_off!
      LibCrypto.rsa_blinding_off(rsa)
      @blinding_on = false
    end
  end
end
