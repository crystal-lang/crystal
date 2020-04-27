require "digest"

module CRC32
  @[Deprecated("Use `Digest::CRC32.initial` instead")]
  def self.initial : UInt32
    Digest::CRC32.initial
  end

  @[Deprecated("Use `Digest::CRC32.checksum` instead")]
  def self.checksum(data) : UInt32
    Digest::CRC32.checksum(data)
  end

  @[Deprecated("Use `Digest::CRC32.update` instead")]
  def self.update(data, crc32 : UInt32) : UInt32
    Digest::CRC32.update(data, crc32)
  end

  @[Deprecated("Use `Digest::CRC32.combine` instead")]
  def self.combine(crc1 : UInt32, crc2 : UInt32, len) : UInt32
    Digest::CRC32.combine(crc1, crc2, len)
  end
end
