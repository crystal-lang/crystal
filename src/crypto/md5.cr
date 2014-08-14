require "openssl/md5"

module Crypto
  class MD5
    def self.hex_digest(data : String)
      hash = OpenSSL::MD5.hash(data)
      hash_str = String.new_with_length(32) do |buffer|
        0.upto(15) do |i|
          buffer[i * 2] = to_hex((hash[i]) >> 4)
          buffer[i * 2 + 1] = to_hex(hash[i] & 0x0f)
        end
      end
    end

    private def self.to_hex(c)
      ((c < 10 ? 48_u8 : 87_u8) + c)
    end
  end
end
