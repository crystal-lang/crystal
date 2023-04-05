require "lib_z"
require "./*"

# The Deflate module contains readers and writers of DEFLATE format compressed
# data, as specified in [RFC 1951](https://www.ietf.org/rfc/rfc1951.txt).
#
# See `Gzip`, `Zip` and `Zlib` for modules that provide access
# to DEFLATE-based file formats.
#
# NOTE: To use `Deflate` or its children, you must explicitly import it with `require "compress/deflate"`
module Compress::Deflate
  NO_COMPRESSION      =  0
  BEST_SPEED          =  1
  BEST_COMPRESSION    =  9
  DEFAULT_COMPRESSION = -1

  enum Strategy
    FILTERED     = 1
    HUFFMAN_ONLY = 2
    RLE          = 3
    FIXED        = 4
    DEFAULT      = 0
  end

  class Error < Exception
    def initialize(ret, stream)
      msg = stream.msg
      msg = LibZ.zError(ret) if msg.null?

      if msg
        error_msg = String.new(msg)
        super("deflate: #{error_msg}")
      else
        super("deflate: #{ret}")
      end
    end
  end
end
