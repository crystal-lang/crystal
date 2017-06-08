require "secure_random"
require "./uuid/*"

# Universally Unique IDentifier.
#
# Supports custom variants with arbitrary 16 bytes as well as (RFC 4122)[https://www.ietf.org/rfc/rfc4122.txt] variant
# versions.
struct UUID
  # Internal representation.
  @data = StaticArray(UInt8, 16).new

  # Generates RFC 4122 v4 UUID.
  def initialize
    initialize Version::V4
  end

  # Generates UUID from static 16-`bytes`.
  def initialize(bytes : StaticArray(UInt8, 16))
    @data = bytes
  end

  # Creates UUID from 16-`bytes` slice.
  def initialize(bytes : Slice(UInt8))
    raise ArgumentError.new "Invalid bytes length #{bytes.size}, expected 16." if bytes.size != 16
    @data.to_unsafe.copy_from bytes
  end

  # Creates UUID from string `value`. See `UUID#decode(value : String)` for details on supported string formats.
  def initialize(value : String)
    decode value
  end

  # Returns 16-byte slice.
  def to_slice
    Slice(UInt8).new to_unsafe, 16
  end

  # Returns unsafe pointer to 16-bytes.
  def to_unsafe
    @data.to_unsafe
  end

  # Writes hyphenated format string to `io`.
  def to_s(io : IO)
    io << to_s
  end

  # Returns `true` if `other` string represents the same UUID, `false` otherwise.
  def ==(other : String)
    self == UUID.new other
  end

  # Returns `true` if `other` 16-byte slice represents the same UUID, `false` otherwise.
  def ==(other : Slice(UInt8))
    to_slice == other
  end

  # Returns `true` if `other` static 16 bytes represent the same UUID, `false` otherwise.
  def ==(other : StaticArray(UInt8, 16))
    self.==(Slice(UInt8).new other.to_unsafe, 16)
  end
end
