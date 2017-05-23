require "openssl/lib_crypto"

# :nodoc:
module OpenSSL::X509
  # :nodoc:
  class Extension
    def self.new(oid : String, value : String, critical = false)
      nid = LibCrypto.obj_ln2nid(oid)
      nid = LibCrypto.obj_sn2nid(oid) if nid == LibCrypto::NID_undef
      raise Error.new("OBJ_sn2nid") if nid == LibCrypto::NID_undef
      new(nid, value, critical)
    end

    def initialize(nid : Int32, value : String, critical = false)
      valstr = String.build do |str|
        str << "critical," if critical
        str << value
      end
      @ext = LibCrypto.x509v3_ext_nconf_nid(nil, nil, nid, valstr)
      raise Error.new("X509V3_EXT_nconf_nid") if @ext.null?
    end

    def initialize(ext : LibCrypto::X509_EXTENSION)
      @ext = LibCrypto.x509_extension_dup(ext)
      raise Error.new("X509_EXTENSION_dup") if @ext.null?
    end

    def finalize
      LibCrypto.x509_extension_free(@ext)
    end

    def dup
      self.class.new(@ext)
    end

    def to_unsafe
      @ext
    end

    def nid
      obj = LibCrypto.x509_extension_get_object(@ext)
      LibCrypto.obj_obj2nid(obj)
    end

    def oid
      obj = LibCrypto.x509_extension_get_object(@ext)
      LibCrypto.obj_obj2nid(obj)

      if (nid = LibCrypto.obj_obj2nid(obj)) == LibCrypto::NID_undef
        buf = Bytes.new(512)
        LibCrypto.i2t_asn1_object(buf, buf.size, obj)
      else
        buf = LibCrypto.obj_nid2sn(nid)
      end

      String.new(buf)
    end

    def value
      bio = OpenSSL::BIO.new(io = IO::Memory.new)

      if LibCrypto.x509v3_ext_print(bio, @ext, 0, 0) == 0
        LibCrypto.asn1_string_print(bio, LibCrypto.x509_extension_get_data(@ext))
      end

      io.to_s
    end
  end
end
