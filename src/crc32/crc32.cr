require "lib_z"

module CRC32
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
end
