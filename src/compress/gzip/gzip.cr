require "compress/deflate"
require "digest/crc32"

# The Gzip module contains readers and writers of gzip format compressed
# data, as specified in [RFC 1952](https://www.ietf.org/rfc/rfc1952.txt).
#
# NOTE: To use `Gzip` or its children, you must explicitly import it with `require "compress/gzip"`
module Compress::Gzip
  NO_COMPRESSION      = Compress::Deflate::NO_COMPRESSION
  BEST_SPEED          = Compress::Deflate::BEST_SPEED
  BEST_COMPRESSION    = Compress::Deflate::BEST_COMPRESSION
  DEFAULT_COMPRESSION = Compress::Deflate::DEFAULT_COMPRESSION

  private ID1     = 0x1f_u8
  private ID2     = 0x8b_u8
  private DEFLATE =    8_u8

  class Error < Exception
  end
end

require "./*"
