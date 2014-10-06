require "openssl/lib_crypto"

module SecureRandom
  def self.hex(n = 16)
    random_bytes(n).hexstring
  end

  def self.random_bytes(n = 16)
    if n < 0
      raise ArgumentError.new "negative size: #{n}"
    end

    slice = Slice(UInt8).new(n)
    result = LibCrypto.rand_bytes slice, n
    if result != 1
      error = LibCrypto.err_get_error
      error_string = String.new LibCrypto.err_error_string(error, nil)
      raise error_string
    end
    slice
  end
end
