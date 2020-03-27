require "deflate"
require "digest/adler32"
require "./*"

# The Zlib module contains readers and writers of zlib format compressed
# data, as specified in [RFC 1950](https://www.ietf.org/rfc/rfc1950.txt).
module Zlib
  NO_COMPRESSION      = Deflate::NO_COMPRESSION
  BEST_SPEED          = Deflate::BEST_SPEED
  BEST_COMPRESSION    = Deflate::BEST_COMPRESSION
  DEFAULT_COMPRESSION = Deflate::DEFAULT_COMPRESSION

  class Error < Exception
  end
end
