require "flate"
require "adler32"
require "./*"

# The Zlib module contains readers and writers of zlib format compressed
# data, as specified in [RFC 1950](https://www.ietf.org/rfc/rfc1950.txt).
module Zlib
  NO_COMPRESSION      = Flate::NO_COMPRESSION
  BEST_SPEED          = Flate::BEST_SPEED
  BEST_COMPRESSION    = Flate::BEST_COMPRESSION
  DEFAULT_COMPRESSION = Flate::DEFAULT_COMPRESSION

  class Error < Exception
  end
end
