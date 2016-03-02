require "../lib_crypto"
require "./pkey"

module OpenSSL
  class PKey::DSA < PKey
    class DSAError < PKeyError; end

    def self.new(pem : String, password = nil)
      self.new(MemoryIO.new(pem), password)
    end

    def self.new(io : IO, password = nil)
      bio = MemBIO.new
      IO.copy(io, bio)
      priv_key = true
      # FIXME: password callback
      dsa = LibCrypto.pem_read_bio_dsaprivatekey(bio, nil, nil, nil)
      unless dsa
        bio.reset
        dsa = LibCrypto.d2i_dsaprivatekey_bio(bio, nil)
      end
      unless dsa
        bio.reset
        dsa = LibCrypto.d2i_dsa_pubkey_bio(bio, nil)
        priv_key = false
      end
      unless dsa
        raise DSAError.new "Neither PUB or PRIV key"
      end
      new(priv_key).tap do |pkey|
        LibCrypto.evp_pkey_assign(pkey, LibCrypto::NID_dsa, dsa as Pointer(Void))
      end
    end

    def self.generate(size)
      seed = uninitialized UInt8[20]
      if LibCrypto.rand_bytes(seed.to_slice, 20) == 0
        raise DSAError.new
      end
      dsa = LibCrypto.dsa_generate_parameters(size, seed.to_slice, 20, out counter, out h, nil, nil)
      unless dsa
        raise DSAError.new
      end
      if LibCrypto.dsa_generate_key(dsa) == 0
        LibCrypto.dsa_free(dsa)
        raise DSAError.new
      end
      new(true).tap do |pkey|
        LibCrypto.evp_pkey_assign(pkey, LibCrypto::NID_dsa, dsa as Pointer(Void))
      end
    end

    def to_pem(io)
      bio = MemBIO.new
      if private_key?
        LibCrypto.pem_write_bio_dsaprivatekey(bio, dsa, nil, nil, 0, nil, nil)
      else
        LibCrypto.pem_write_bio_dsa_pubkey(bio, dsa)
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
          LibCrypto.i2d_dsaprivatekey(dsa, buf)
        else
          LibCrypto.i2d_dsa_pubkey(dsa, buf)
        end
      }
      len = fn.call(nil)
      if len <= 0
        raise DSAError.new
      end
      slice = Slice(UInt8).new(len)
      p = slice.to_unsafe
      len = fn.call(pointerof(p))
      slice[0, len]
    end

    def public_key
      f1 = ->LibCrypto.i2d_dsapublickey
      f2 = ->LibCrypto.d2i_dsapublickey
      pub_dsa = LibCrypto.asn1_dup(f1.pointer, f2.pointer, dsa as Void*) as DSA
      DSA.new(false).tap do |pkey|
        LibCrypto.evp_pkey_assign(pkey, LibCrypto::NID_dsa, pub_dsa as Pointer(Void))
      end
    end

    def dsa_sign(data)
      unless private_key?
        raise DSAError.new "need a private key"
      end
      data = data.to_slice
      to = Slice(UInt8).new max_encrypt_size
      if LibCrypto.dsa_sign(0, data, data.size, to, out len, dsa) == 0
        raise DSAError.new
      end
      to[0, len]
    end

    def dsa_verify(digest, signature)
      digest = digest.to_slice
      signature = signature.to_slice
      case LibCrypto.dsa_verify(0, digest, digest.size, signature, signature.size, dsa)
      when 1
        true
      when 0
        false
      else
        raise DSAError.new
      end
    end

    private def dsa
      LibCrypto.evp_pkey_get1_dsa(self)
    end

    private def max_encrypt_size
      LibCrypto.dsa_size(dsa)
    end
  end
end
