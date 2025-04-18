require "./lib_ssl"
require "./lib_crypto"

module OpenSSL
  class Error < Exception
    getter! code : LibCrypto::ULong

    def initialize(message : String? = nil, fetched : Bool = false, cause : Exception? = nil)
      @code ||= LibCrypto::ULong.new(0)

      if fetched
        super(message, cause: cause)
      else
        @code, error = fetch_error_details
        super(message ? "#{message}: #{error}" : error, cause: cause)
      end
    end

    protected def fetch_error_details : Tuple(UInt64, String)
      code = LibCrypto.err_get_error
      message = String.new(LibCrypto.err_error_string(code, nil)) unless code == 0
      {code, message || "Unknown or no error"}
    end

    protected def get_reason(code : UInt64) : Int32
      {% if LibCrypto.has_constant?(:ERR_REASON_MASK) %}
        if (code & LibCrypto::ERR_SYSTEM_FLAG) != 0
          (code & LibCrypto::ERR_SYSTEM_MASK).to_i
        else
          (code & LibCrypto::ERR_REASON_MASK).to_i
        end
      {% else %}
        (code & 0xFFF).to_i
      {% end %}
    end
  end
end
