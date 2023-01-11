require "compress/deflate"
require "digest/crc32"

# The Compress::Zip module contains readers and writers of the zip
# file format, described at [PKWARE's site](https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.3.TXT).
#
# ### Reading zip files
#
# Two types are provided to read from zip files:
# * `Compress::Zip::File`: can read zip entries from a `File` or from an `IO::Memory`
# and provides random read access to its entries.
# * `Compress::Zip::Reader`: can only read zip entries sequentially from any `IO`.
#
# `Compress::Zip::File` is the preferred method to read zip files if you
# can provide a `File`, because it's a bit more flexible and provides
# more complete information for zip entries (such as comments).
#
# When reading zip files, CRC32 checksum values are automatically
# verified when finishing reading an entry, and `Compress::Zip::Error` will
# be raised if the computed CRC32 checksum does not match.
#
# ### Writer zip files
#
# Use `Compress::Zip::Writer`, which writes zip entries sequentially to
# any `IO`.
#
# NOTE: only compression methods 0 (STORED) and 8 (DEFLATED) are
# supported. Additionally, ZIP64 is not yet supported.
module Compress::Zip
  VERSION = 20_u8

  {% if flag?(:unix) %}
    FS_ORIGIN = 3_u8 # Unix
  {% elsif flag?(:win32) %}
    FS_ORIGIN = 0_u8 # # MS-DOS, OS/2, or NT FAT
  {% else %}
    {% raise "No FS_ORIGIN implementation available" %}
  {% end %}
  FS_EXTRACT = 0_u8 # MS-DOS, OS/2, or NT FAT

  CENTRAL_DIRECTORY_HEADER_SIGNATURE        = 0x02014b50
  END_OF_CENTRAL_DIRECTORY_HEADER_SIGNATURE = 0x06054b50

  class Error < Exception
  end
end

require "./*"
