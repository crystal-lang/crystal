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

    def subject
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

    def extensions
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
  end
end
