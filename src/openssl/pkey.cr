require "./cipher"

module OpenSSL
  abstract class PKey
    class PKeyError < OpenSSL::Error; end

    def initialize(@pkey : LibCrypto::EvpPKey*, @is_private : Bool)
      raise PKeyError.new "Invalid EVP_PKEY" unless @pkey
    end

    def initialize(is_private)
      initialize(LibCrypto.evp_pkey_new, is_private)
    end

    def self.new(encoded : String, passphrase = nil, is_private = true)
      self.new(IO::Memory.new(encoded), passphrase, is_private)
    end

    def self.new(io : IO, passphrase = nil, is_private = true)
      begin
        bio = OpenSSL::BIO.new(io)
        new(LibCrypto.pem_read_bio_private_key(bio, nil, nil, passphrase), is_private)
      rescue
        bio = OpenSSL::BIO.new(IO::Memory.new(Base64.decode(io.to_s)))
        new(LibCrypto.d2i_private_key_bio(bio, nil), is_private)
      end
    end

    def self.new(size : Int32)
      exponent = 65537.to_u32
      self.generate(size, exponent)
    end

    def to_unsafe
      @pkey
    end

    def finalize
      LibCrypto.evp_pkey_free(self)
    end

    def private?
      @is_private
    end

    def public?
      !private?
    end

    def to_pem(io : IO, cipher : (OpenSSL::Cipher | Nil) = nil, passphrase = nil)
      bio = BIO.new(io)

      if private?
        cipher_pointer = nil

        if !cipher.nil?
          unsafe = cipher.to_unsafe
          cipher_pointer = pointerof(unsafe)
        end

        raise PKeyError.new "Could not write to PEM" unless LibCrypto.pem_write_bio_pkcs8_private_key(bio, self, cipher_pointer, nil, 0, passphrase_callback, Box.box(passphrase)) == 1
      else
        raise PKeyError.new "Could not write to PEM" unless LibCrypto.pem_write_bio_public_key(bio, self) == 1
      end
    end

    def to_pem(cipher : OpenSSL::Cipher, passphrase)
      io = IO::Memory.new
      to_pem(io, cipher, passphrase)
      io.to_s
    end

    def to_pem
      io = IO::Memory.new
      to_pem(io)
      io.to_s
    end

    def to_der
      io = IO::Memory.new
      to_der(io)
      Base64.encode(io.to_s)
    end

    def to_der(io)
      fn = ->(buf : UInt8** | Nil) {
        if private?
          LibCrypto.i2d_private_key(self, buf)
        else
          LibCrypto.i2d_public_key(self, buf)
        end
      }

      len = fn.call(nil)
      if len <= 0
        raise PKeyError.new "Could not output in DER format"
      end
      slice = Slice(UInt8).new(len)
      p = slice.to_unsafe
      len = fn.call(pointerof(p))

      output = slice[0, len]
      io.write(output)
    end

    private def passphrase_callback
      ->(buffer : UInt8*, key_size : Int32, is_read_write : Int32, u : Void*) {
        pwd = Box(String).unbox(u)

        if pwd.nil?
          return 0
        end

        len = pwd.bytesize

        if len <= 0
          return 0
        end

        if len > key_size
          len = key_size
        end

        buffer.copy_from(pwd.to_slice.pointer(len), len)

        return len
      }
    end

    private def max_encrypt_size
      LibCrypto.evp_pkey_size(self)
    end
  end
end
