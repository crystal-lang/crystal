require "base64"
require "openssl/lib_crypto"

module SecureRandom
  def self.base64(n = 16)
    Base64.strict_encode64(random_bytes(n))
  end

  def self.urlsafe_base64(n = 16, padding = false)
    Base64.urlsafe_encode64(random_bytes(n), padding)
  end

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

  def self.uuid
    bytes = random_bytes(16)
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80

    String.new(36) do |buffer|
      buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
      bytes[0, 4].hexstring(buffer + 0)
      bytes[4, 2].hexstring(buffer + 9)
      bytes[6, 2].hexstring(buffer + 14)
      bytes[8, 2].hexstring(buffer + 19)
      bytes[10, 6].hexstring(buffer + 24)
      {36, 36}
    end
  end
end
