require "./openssl/lib_ssl"

module OpenSSL
  class Error < Exception
    getter! code : LibCrypto::ULong?

    def initialize(message = nil, fetched = false)
      @code ||= LibCrypto::ULong.new(0)

      if fetched
        super(message)
      else
        @code, error = fetch_error_details
        super(message ? "#{message}: #{error}" : error)
      end
    end

    protected def fetch_error_details
      code = LibCrypto.err_get_error
      message = String.new(LibCrypto.err_error_string(code, nil)) unless code == 0
      {code, message || "Unknown or no error"}
    end
  end

  module SSL
    alias Modes = LibSSL::Modes
    alias Options = LibSSL::Options
    alias VerifyMode = LibSSL::VerifyMode
    alias ErrorType = LibSSL::SSLError
    {% if LibSSL::OPENSSL_102 %}
    alias X509VerifyFlags = LibCrypto::X509VerifyFlags
    {% end %}

    class Error < OpenSSL::Error
      getter error : ErrorType

      def initialize(ssl : LibSSL::SSL, return_code : LibSSL::Int, func = nil)
        @error = LibSSL.ssl_get_error(ssl, return_code)

        case @error
        when .none?
          message = "Raised erroneously"
        when .syscall?
          @code, message = fetch_error_details
          if @code == 0
            case return_code
            when 0
              message = "Unexpected EOF"
            when -1
              raise Errno.new(func || "OpenSSL")
            else
              message = "Unknown error"
            end
          end
        when .ssl?
          @code, message = fetch_error_details
        else
          message = @error.to_s
        end

        super(func ? "#{func}: #{message}" : message, true)
      end
    end
  end
end

require "./openssl/bio"
require "./openssl/ssl/*"
require "./openssl/digest/*"
require "./openssl/md5"
require "./openssl/x509/x509"
