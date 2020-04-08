require "digest"

module Adler32
  @[Deprecated("Use `Digest::Adler32.initial` instead")]
  def self.initial : UInt32
    Digest::Adler32.initial
  end

  @[Deprecated("Use `Digest::Adler32.checksum` instead")]
  def self.checksum(data) : UInt32
    Digest::Adler32.checksum(data)
  end

  @[Deprecated("Use `Digest::Adler32.update` instead")]
  def self.update(data, adler32 : UInt32) : UInt32
    Digest::Adler32.update(data, adler32)
  end

  @[Deprecated("Use `Digest::Adler32.combine` instead")]
  def self.combine(adler1 : UInt32, adler2 : UInt32, len) : UInt32
    Digest::Adler32.combine(adler1, adler2, len)
  end
end
