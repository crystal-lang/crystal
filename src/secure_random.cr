require "base64"
require "openssl/lib_crypto"

# The SecureRandom module is an interface for creating secure random values in different formats.
# It uses the RNG (random number generator) of libcrypto (OpenSSL).
#
# For example:
# ```crystal
# SecureRandom.base64 #=> "LIa9s/zWzJx49m/9zDX+VQ=="
# SecureRandom.hex    #=> "c8353864ff9764a39ef74983ec0d4a38"
# SecureRandom.uuid   #=> "c7ee4add-207f-411a-97b7-0d22788566d6"
# ```
module SecureRandom
  # Generates *n* random bytes that are encoded into Base64.
  #
  # Check `Base64#strict_encode` for details.
  #
  # ```crystal
  # SecureRandom.base64(4) #=> "fK1eYg=="
  # ```
  def self.base64(n = 16 : Int) : String
    Base64.strict_encode(random_bytes(n))
  end

  # URL-safe variant of `#base64`
  #
  # Check `Base64#urlsafe_encode` for details.
  #
  # ```crystal
  # SecureRandom.urlsafe_base64          #=> "MAD2bw8QaBdvITCveBNCrw"
  # SecureRandom.urlsafe_base64(8,true)  #=> "vvP1kcs841I="
  # SecureRandom.urlsafe_base64(16,true) #=> "og2aJrELDZWSdJfVGkxNKw=="
  # ```
  def self.urlsafe_base64(n = 16 : Int, padding = false) : String
    Base64.urlsafe_encode(random_bytes(n), padding)
  end

  # Generates a hexadecimal string based on *n* random bytes.
  #
  # The bytes are encoded into a string of a two-digit hexadecimal number (00-ff) per byte.
  #
  # ```crystal
  # SecureRandom.hex    #=> "05f100a1123f6bdbb427698ab664ff5f"
  # SecureRandom.hex(1) #=> "1a"
  # ```
  def self.hex(n = 16 : Int) : String
    random_bytes(n).hexstring
  end

  # Generates a slice filled with *n* random bytes.
  #
  # ```crystal
  # SecureRandom.random_bytes    #=> [145, 255, 191, 133, 132, 139, 53, 136, 93, 238, 2, 37, 138, 244, 3, 216]
  # SecureRandom.random_bytes(4) #=> [217, 118, 38, 196]
  # ```
  def self.random_bytes(n = 16 : Int) : Slice(UInt8)
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

  # Generates a UUID (Universally Unique Identifier)
  #
  # It generates a random v4 UUID. Check [RFC 4122 Section 4.4](https://tools.ietf.org/html/rfc4122#section-4.4)
  # for the used algorithm and its implications.
  #
  # ```crystal
  # SecureRandom.uuid #=> "a4e319dd-a778-4a51-804e-66a07bc63358"
  # ```
  def self.uuid : String
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
