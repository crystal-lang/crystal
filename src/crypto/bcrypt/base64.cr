require "../bcrypt"

# :nodoc:
module Crypto::Bcrypt::Base64
  ALPHABET = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

  TABLE = Int8[
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, 0, 1, 54, 55,
    56, 57, 58, 59, 60, 61, 62, 63, -1, -1,
    -1, -1, -1, -1, -1, 2, 3, 4, 5, 6,
    7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
    -1, -1, -1, -1, -1, -1, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, -1, -1, -1, -1, -1,
  ]

  def self.encode(d, len) : String
    off = 0

    String.build do |str|
      loop do
        c1 = d[off] & 0xff
        off += 1
        str << ALPHABET[(c1 >> 2) & 0x3f]
        c1 = (c1 & 0x03) << 4

        if off >= len
          str << ALPHABET[c1 & 0x3f]
          break
        end

        c2 = d[off] & 0xff
        off += 1
        c1 |= (c2 >> 4) & 0x0f
        str << ALPHABET[c1 & 0x3f]
        c1 = (c2 & 0x0f) << 2

        if off >= len
          str << ALPHABET[c1 & 0x3f]
          break
        end

        c2 = d[off] & 0xff
        off += 1
        c1 |= (c2 >> 6) & 0x03
        str << ALPHABET[c1 & 0x3f]
        str << ALPHABET[c2 & 0x3f]

        break if off >= len
      end
    end
  end

  def self.decode(string, maxolen) : Bytes
    off, slen, olen = 0, string.size, 0

    i = -1
    str = Bytes.new(maxolen)

    while off < slen - 1 && olen < maxolen
      c1, c2 = char64(string[off]), char64(string[off + 1])
      break if c1 == -1 || c2 == -1
      off += 2

      str[i += 1] = ((c1 << 2) | (c2 & 0x30) >> 4).to_u8
      break if (olen += 1) >= maxolen || off >= slen

      c3 = char64(string[off])
      break if c3 == -1
      off += 1

      str[i += 1] = (((c2 & 0x0f) << 4) | ((c3 & 0x3c) >> 2)).to_u8
      break if (olen += 1) >= maxolen || off >= slen

      c4 = char64(string[off])
      str[i += 1] = (((c3 & 0x03) << 6) | c4).to_u8
      off += 1
      olen += 1
    end

    str[0, olen]
  end

  private def self.char64(x)
    TABLE[x.ord]? || -1
  end
end
