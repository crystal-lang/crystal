require "./lib_zlib"
require "./deflate"
require "./inflate"

module Zlib
  def self.version
    String.new LibZ.zlibVersion()
  end

  def self.adler32(data, adler)
    slice = data.to_slice
    LibZ.adler32(LibC::ULong.new(adler), slice, LibC::UInt.new(slice.size))
  end

  def self.adler32(data)
    adler = LibZ.adler32(LibC::ULong.new(0), nil, LibC::UInt.new(0))
    adler32(data, adler)
  end

  def self.adler32_combine(adler1, adler2, len)
    LibZ.adler32_combine(LibC::ULong.new(adler1), LibC::ULong.new(adler2), LibC::Long.new(len))
  end

  def self.crc32(data, crc)
    slice = data.to_slice
    LibZ.crc32(LibC::ULong.new(crc), slice, LibC::UInt.new(slice.size))
  end

  def self.crc32(data)
    crc = LibZ.crc32(LibC::ULong.new(0), nil, LibC::UInt.new(0))
    crc32(data, crc)
  end

  def self.crc32_combine(crc1, crc2, len)
    LibZ.crc32_combine(LibC::ULong.new(crc1), LibC::ULong.new(crc2), LibC::Long.new(len))
  end

  class ZlibError < Exception
    def self.check_error(err, msg)
      case err
      when LibZ::OK, LibZ::STREAM_END
      when LibZ::NEED_DICT
        raise NeedDictError.new(err, msg)
      when LibZ::ERRNO
        raise Errno.new msg
      when LibZ::STREAM_ERROR
        raise StreamError.new(err, msg)
      when LibZ::DATA_ERROR
        raise DataError.new(err, msg)
      when LibZ::BUF_ERROR
        raise BufError.new(err, msg)
      when LibZ::VERSION_ERROR
        raise VersionError.new(err, msg)
      else
        raise ZStreamError.new(err, msg)
      end
    end
  end

  class ZStreamError < ZlibError
    def initialize(@code, @msg)
      super("#{@code}: #{@msg}")
    end
  end
  class NeedDictError < ZStreamError; end
  class StreamError < ZStreamError; end
  class DataError < ZStreamError; end
  class MemError < ZStreamError; end
  class BufError < ZStreamError; end
  class VersionError < ZStreamError; end
end
