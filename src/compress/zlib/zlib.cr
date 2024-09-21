require "compress/deflate"
require "digest/adler32"

# The Compress::Zlib module contains readers and writers of zlib format compressed
# data, as specified in [RFC 1950](https://www.ietf.org/rfc/rfc1950.txt).
#
# NOTE: To use `Zlib` or its children, you must explicitly import it with `require "compress/zlib"`
module Compress::Zlib
  NO_COMPRESSION      = Compress::Deflate::NO_COMPRESSION
  BEST_SPEED          = Compress::Deflate::BEST_SPEED
  BEST_COMPRESSION    = Compress::Deflate::BEST_COMPRESSION
  DEFAULT_COMPRESSION = Compress::Deflate::DEFAULT_COMPRESSION

  class Error < Exception
  end
end

require "./*"
