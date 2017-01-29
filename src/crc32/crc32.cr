require "lib_z"

module CRC32
  def self.initial : UInt32
    LibZ.crc32(0, nil, 0).to_u32
  end

  def self.checksum(slice : Bytes) : UInt32
    update(slice, initial)
  end

  def self.checksum(string : String) : UInt32
    checksum(string.to_slice)
  end

  def self.update(slice : Bytes, crc32 : UInt32) : UInt32
    LibZ.crc32(crc32, slice, slice.size).to_u32
  end

  def self.update(string : String, crc32 : UInt32) : UInt32
    update(string.to_slice, crc32)
  end

  def self.combine(crc1 : UInt32, crc2 : UInt32, len) : UInt32
    LibZ.crc32_combine(crc1, crc2, len).to_u32
  end
end
