require "openssl/lib_crypto"
require "./extension"
require "./name"

# :nodoc:
module OpenSSL::X509
  # :nodoc:
  class Certificate
    def initialize
      @cert = LibCrypto.x509_new
      raise Error.new("X509_new") if @cert.null?
    end

    def initialize(cert : LibCrypto::X509)
      @cert = LibCrypto.x509_dup(cert)
      raise Error.new("X509_dup") if @cert.null?
    end

    def finalize
      LibCrypto.x509_free(@cert)
    end

    def dup
      self.class.new(@cert)
    end

    def to_unsafe
      @cert
    end

    # Attempts to decode an ASN.1/DER-encoded certificate from *bytes*.
    #
    # Returns the decoded certificate and the remaining bytes on success.
    # Returns `nil` and *bytes* unchanged on failure.
    def self.from_der?(bytes : Bytes) : {self?, Bytes}
      ptr = bytes.to_unsafe
      if x509 = LibCrypto.d2i_X509(nil, pointerof(ptr), bytes.size)
        {new(x509), bytes[ptr - bytes.to_unsafe..]}
      else
        {nil, bytes}
      end
    end

    def subject : X509::Name
      subject = LibCrypto.x509_get_subject_name(@cert)
      raise Error.new("X509_get_subject_name") if subject.null?
      Name.new(subject)
    end

    # Sets the subject.
    #
    # Refer to `Name.parse` for the format.
    def subject=(subject : String)
      self.subject = Name.parse(subject)
    end

    def subject=(subject : Name)
      ret = LibCrypto.x509_set_subject_name(@cert, subject)
      raise Error.new("X509_set_subject_name") if ret == 0
      subject
    end

    def extensions : Array(X509::Extension)
      count = LibCrypto.x509_get_ext_count(@cert)
      Array(Extension).new(count) do |i|
        Extension.new(LibCrypto.x509_get_ext(@cert, i))
      end
    end

    def add_extension(extension : Extension)
      ret = LibCrypto.x509_add_ext(@cert, extension, -1)
      raise Error.new("X509_add_ext") if ret.null?
      extension
    end

    # Returns the name of the signature algorithm.
    def signature_algorithm : String
      {% if LibCrypto.has_method?(:obj_find_sigid_algs) %}
        sigid = LibCrypto.x509_get_signature_nid(@cert)
        result = LibCrypto.obj_find_sigid_algs(sigid, out algo_nid, nil)
        raise "Could not determine certificate signature algorithm" if result == 0

        sn = LibCrypto.obj_nid2sn(algo_nid)
        raise "Unknown algo NID #{algo_nid.inspect}" if sn.null?
        String.new sn
      {% else %}
        raise "Missing OpenSSL function for certificate signature algorithm (requires OpenSSL 1.0.2)"
      {% end %}
    end

    # Returns the digest of the certificate using *algorithm_name*
    #
    # ```
    # cert = OpenSSL::X509::Certificate.new
    # cert.digest("SHA1").hexstring   # => "6f608752059150c9b3450a9fe0a0716b4f3fa0ca"
    # cert.digest("SHA256").hexstring # => "51d80c865cc717f181cd949f0b23b5e1e82c93e01db53f0836443ec908b83748"
    # ```
    def digest(algorithm_name : String) : Bytes
      algo_type = LibCrypto.evp_get_digestbyname algorithm_name
      raise ArgumentError.new "Could not find digest for #{algorithm_name.inspect}" if algo_type.null?
      hash = Bytes.new(64) # EVP_MAX_MD_SIZE for SHA512
      result = LibCrypto.x509_digest(@cert, algo_type, hash, out size)
      raise Error.new "Could not generate certificate hash" unless result == 1

      hash[0, size]
    end
  end
end
