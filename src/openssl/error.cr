require "./lib_ssl"
require "./lib_crypto"

module OpenSSL
  class Error < Exception
    getter! code : LibCrypto::ULong

    def initialize(message = nil, fetched = false, cause : Exception? = nil)
      @code ||= LibCrypto::ULong.new(0)

      if fetched
        super(message, cause: cause)
      else
        @code, error = fetch_error_details
        super(message ? "#{message}: #{error}" : error, cause: cause)
      end
    end

    protected def fetch_error_details
      code = LibCrypto.err_get_error
      message = String.new(LibCrypto.err_error_string(code, nil)) unless code == 0
      {code, message || "Unknown or no error"}
    end
  end
end
