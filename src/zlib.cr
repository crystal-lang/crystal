require "./zlib/*"

# The Zlib module provides access to the [zlib library](http://zlib.net/) for
# lossless data compression and decompression in zlib and gzip format:
#
# * `Zlib::Deflate` for compression
# * `Zlib::Inflate` for decompression
module Zlib
  GZIP = LibZ::MAX_BITS + 16

  # Returns the linked zlib version.
  def self.version : String
    String.new LibZ.zlibVersion
  end

  def self.adler32(data, adler)
    slice = data.to_slice
    LibZ.adler32(adler, slice, slice.size)
  end

  def self.adler32(data)
    adler = LibZ.adler32(0, nil, 0)
    adler32(data, adler)
  end

  def self.adler32_combine(adler1, adler2, len)
    LibZ.adler32_combine(adler1, adler2, len)
  end

  def self.crc32(data, crc)
    slice = data.to_slice
    LibZ.crc32(crc, slice, slice.size)
  end

  def self.crc32(data)
    crc = LibZ.crc32(0, nil, 0)
    crc32(data, crc)
  end

  def self.crc32_combine(crc1, crc2, len)
    LibZ.crc32_combine(crc1, crc2, len)
  end

  class Error < Exception
    def initialize(ret, stream)
      if msg = stream.msg
        error_msg = String.new(msg)
        super("inflate: #{error_msg} #{ret}")
      else
        super("inflate: #{ret}")
      end
    end
  end
end
