require "../openssl"

module OpenSSL::X509
  class X509Error < OpenSSL::Error; end

  class Name
    enum Flags
      COMPAT         = 0
      SEP_COMMA_PLUS = 1 << 16
      SEP_CPLUS_SPC  = 2 << 16
      SEP_SPLUS_SPC  = 3 << 16
      SEP_MULTILINE  = 4 << 16
    end

    def initialize(@handle : LibCrypto::X509_NAME)
      raise X509Error.new "invalid handle" unless @handle
    end

    def name(flag = Flags::COMPAT : Flags)
      bio = MemBIO.new
      if LibCrypto.x509_name_print_ex(bio, self, 0, flag.value.to_u64) == 0
        raise X509Error.new
      end
      bio.to_string
    end

    def finalize
      LibCrypto.x509_name_free(self)
    end

    def to_unsafe
      @handle
    end

    def to_s(io)
      io << name
    end

    def inspect(io)
      io << "X509::Name [" << name << "]"
    end
  end

  class Certificate
    def initialize(@handle : LibCrypto::X509)
      raise X509Error.new "invalid handle" unless @handle
    end

    def initialize
      initialize LibCrypto.x509_new
    end

    def self.from_pem(io)
      bio = MemBIO.new
      IO.copy(io, bio)
      x509 = LibCrypto.pem_read_bio_x509(bio, nil, nil, nil)
      new(x509)
    end

    def finalize
      LibCrypto.x509_free(self)
    end

    def to_unsafe
      @handle
    end

    def public_key
      PKey::RSA.new(LibCrypto.x509_get_pubkey(self), false)
    end

    def subject_name
      handle = LibCrypto.x509_get_subject_name(self)
      Name.new LibCrypto.x509_name_dup(handle)
    end

    def fingerprint(digest = OpenSSL::Digest.new("SHA1") : OpenSSL::Digest)
      slice = Slice(UInt8).new digest.digest_size
      if LibCrypto.x509_digest(self, digest.to_unsafe_md, slice, out len) == 0
        raise X509Error.new
      end
      if len != slice.size
        raise X509Error.new "Fingerprint is corrupted"
      end
      slice
    end

    def fingerprint_hex(digest = OpenSSL::Digest.new("SHA1") : OpenSSL::Digest)
      DigestBase.hexdump(fingerprint(digest))
    end

    def verify(pkey)
      ret = LibCrypto.x509_verify(self, pkey)
      if ret < 0
        raise X509Error.new
      end
      ret > 0
    end

    def to_pem(io)
      bio = MemBIO.new
      LibCrypto.pem_write_bio_x509(bio, self)
      IO.copy(bio, io)
    end

    def to_pem
      io = MemoryIO.new
      to_pem(io)
      io.to_s
    end
  end
end
