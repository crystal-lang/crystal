require "openssl/lib_crypto"

# :nodoc:
module OpenSSL::X509
  # :nodoc:
  class Name
    # Parses entries in string and initializes a Name object.
    #
    # Example:
    # ```
    # require "openssl"
    #
    # OpenSSL::X509::Name.parse("CN=nobody/DC=example")
    # ```
    def self.parse(string : String) : Name
      new.tap do |name|
        string.split('/').each do |entry|
          oid, value = entry.split('=')
          name.add_entry(oid, value)
        end
      end
    end

    def initialize
      @name = LibCrypto.x509_name_new
      raise Error.new("X509_NAME_new") if @name.null?
    end

    def initialize(name : LibCrypto::X509_NAME)
      @name = LibCrypto.x509_name_dup(name)
      raise Error.new("X509_NAME_dup") if @name.null?
    end

    def finalize
      LibCrypto.x509_name_free(@name)
    end

    def dup
      self.class.new(@name)
    end

    def to_unsafe
      @name
    end

    # Adds a new entry.
    #
    # Example:
    # ```
    # name = OpenSSL::X509::Name.new
    # name.add_entry "CN", "Nobody"
    # name.add_entry "DC", "example"
    # ```
    def add_entry(oid : String, value : String)
      type = LibCrypto::MBSTRING_UTF8
      ret = LibCrypto.x509_name_add_entry_by_txt(@name, oid, type, value, value.bytesize, -1, 0)
      raise Error.new("X509_NAME_add_entry_by_txt") if ret.null?
    end

    # Returns entries as an Array of oid, value pairs.
    #
    # Example:
    # ```
    # name = OpenSSL::X509::Name.parse("CN=Nobody/DC=example")
    # name.to_a # => [{"CN", "Nobody"}, {"DC", "example"}]
    # ```
    def to_a
      count = LibCrypto.x509_name_entry_count(@name)
      raise Error.new("X509_NAME_entry_count") if count < 0

      long_name = Bytes.new(512)

      Array(Tuple(String, String)).new(count) do |i|
        entry = LibCrypto.x509_name_get_entry(@name, i)
        raise Error.new("X509_NAME_get_entry") if entry.null?

        obj = LibCrypto.x509_name_entry_get_object(entry)
        LibCrypto.i2t_asn1_object(long_name, long_name.size, obj)

        nid = LibCrypto.obj_ln2nid(long_name)
        if nid == LibCrypto::NID_undef
          oid = String.new(long_name)
        else
          short_name = LibCrypto.obj_nid2sn(nid)
          oid = String.new(short_name)
        end

        asn1 = LibCrypto.x509_name_entry_get_data(entry)
        str = LibCrypto.asn1_string_data(asn1)
        str_len = LibCrypto.asn1_string_length(asn1)

        {oid, String.new(str, str_len)}
      end
    end
  end
end
