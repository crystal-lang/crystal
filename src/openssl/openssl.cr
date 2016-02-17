require "./lib_ssl"

module OpenSSL
  class Error < Exception
    getter err
    getter err_msg

    def initialize(msg = nil)
      unless (err = @err = LibCrypto.err_get_error) == 0
        @err_msg = String.new(LibCrypto.err_error_string(err, nil))
        msg = msg ? "#{msg}: #{@err_msg}" : @err_msg
      end
      super(msg)
    end
  end

  LibSSL.ssl_library_init
  LibSSL.ssl_load_error_strings
  LibCrypto.openssl_add_all_algorithms
  LibCrypto.err_load_crypto_strings
end

require "./bio"
require "./ssl/*"
require "./digest/*"
require "./md5"
