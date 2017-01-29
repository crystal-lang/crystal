require "lib_z"

module Adler32
  def self.initial : UInt32
    LibZ.adler32(0, nil, 0).to_u32
  end

  def self.checksum(slice : Bytes) : UInt32
    update(slice, initial)
  end

  def self.checksum(string : String) : UInt32
    checksum(string.to_slice)
  end

  def self.update(slice : Bytes, adler32 : UInt32) : UInt32
    LibZ.adler32(adler32, slice, slice.size).to_u32
  end

  def self.update(string : String, adler32 : UInt32) : UInt32
    update(string.to_slice, adler32)
  end

  def self.combine(adler1 : UInt32, adler2 : UInt32, len) : UInt32
    LibZ.adler32_combine(adler1, adler2, len).to_u32
  end
end
