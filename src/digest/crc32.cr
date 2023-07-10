require "lib_z"
require "./digest"

# Implements the CRC32 checksum algorithm.
#
# NOTE: To use `CRC32`, you must explicitly import it with `require "digest/crc32"`
class Digest::CRC32 < ::Digest
  extend ClassMethods

  @digest : UInt32

  def initialize
    @digest = CRC32.initial
  end

  def self.initial : UInt32
    LibZ.crc32(0, nil, 0).to_u32
  end

  def self.checksum(data) : UInt32
    update(data, initial)
  end

  def self.update(data, crc32 : UInt32) : UInt32
    slice = data.to_slice
    LibZ.crc32(crc32, slice, slice.size).to_u32
  end

  def self.combine(crc1 : UInt32, crc2 : UInt32, len) : UInt32
    LibZ.crc32_combine(crc1, crc2, len).to_u32
  end

  # :nodoc:
  def update_impl(data : Bytes) : Nil
    @digest = CRC32.update(data, @digest)
  end

  # :nodoc:
  def final_impl(dst : Bytes) : Nil
    dst[0] = (@digest >> 24).to_u8!
    dst[1] = (@digest >> 16).to_u8!
    dst[2] = (@digest >> 8).to_u8!
    dst[3] = (@digest).to_u8!
  end

  # :nodoc:
  def reset_impl : Nil
    @digest = CRC32.initial
  end

  # :nodoc:
  def digest_size : Int32
    4
  end
end
