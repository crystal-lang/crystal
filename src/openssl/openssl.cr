require "./lib_ssl"

module OpenSSL
  class Error < Exception
    getter err : LibCrypto::ULong
    getter err_msg : String?

    def initialize(msg = nil)
      unless (err = @err = LibCrypto.err_get_error) == 0
        @err_msg = String.new(LibCrypto.err_error_string(err, nil))
        msg = msg ? "#{msg}: #{@err_msg}" : @err_msg
      end
      super(msg)
    end
  end
end

require "./bio"
require "./ssl/*"
require "./digest/*"
require "./md5"
