require "lib_z"

module Adler32
  def self.initial : UInt32
    LibZ.adler32(0, nil, 0).to_u32
  end

  def self.checksum(data) : UInt32
    update(data, initial)
  end

  def self.update(data, adler32 : UInt32) : UInt32
    slice = data.to_slice
    LibZ.adler32(adler32, slice, slice.size).to_u32
  end

  def self.combine(adler1 : UInt32, adler2 : UInt32, len) : UInt32
    LibZ.adler32_combine(adler1, adler2, len).to_u32
  end
end
