require "./lib_crypto"

module OpenSSL
  # Raised when OpenSSL informs about error.
  class Error < Exception
    getter! code : LibCrypto::ULong

    # Initializes OpenSSL error.
    # Will fetch error details from OpenSSL error queue
    # unless `already_fetched` specified.
    def initialize(message = nil, already_fetched = false)
      @code ||= LibCrypto::ULong.new(0)

      if already_fetched
        super(message)
      else
        @code, error = fetch_error_details
        super(message ? "#{message}: #{error}" : error)
      end
    end

    # Fetches OpenSSL {code, message} from libcrypto.
    protected def fetch_error_details
      code = LibCrypto.err_get_error
      message = String.new(LibCrypto.err_error_string(code, nil)) unless code == 0
      {code, message || "Unknown or no error"}
    end
  end
end
