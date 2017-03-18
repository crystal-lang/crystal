require "flate"
require "crc32"

# The Gzip module contains readers and writers of gzip format compressed
# data, as specified in [RFC 1952](https://www.ietf.org/rfc/rfc1952.txt).
module Gzip
  NO_COMPRESSION      = Flate::NO_COMPRESSION
  BEST_SPEED          = Flate::BEST_SPEED
  BEST_COMPRESSION    = Flate::BEST_COMPRESSION
  DEFAULT_COMPRESSION = Flate::DEFAULT_COMPRESSION

  private ID1     = 0x1f_u8
  private ID2     = 0x8b_u8
  private DEFLATE =    8_u8

  class Error < Exception
  end
end

require "./*"
