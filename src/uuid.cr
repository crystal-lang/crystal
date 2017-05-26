require "secure_random"
require "./uuid/*"

# Universally Unique IDentifier.
#
# Supports custom variants with arbitrary 16 bytes as well as (RFC 4122)[https://www.ietf.org/rfc/rfc4122.txt] variant
# versions.
struct UUID
  # Internal representation.
  @bytes : StaticArray(UInt8, 16)

  # Generates RFC 4122 v4 UUID.
  def initialize
    initialize Version::V4
  end

  # Generates UUID from static 16-`bytes`.
  def initialize(@bytes : StaticArray(UInt8, 16))
    initialize Version::V4, @bytes
  end

  # Creates UUID from 16-`bytes` slice.
  def initialize(new_bytes : Slice(UInt8))
    if new_bytes.size != 16
      raise ArgumentError.new "Invalid bytes length #{@bytes.size}, expected 16."
    end
    @bytes = nil
    @bytes.to_unsafe.copy_from new_bytes
  end

  # Creates UUID from string `value`. See `UUID#decode(value : String)` for details on supported string formats.
  def initialize(value : String)
    @bytes = uninitialized UInt8[16]
    decode value
  end

  # Returns 16-byte slice.
  def to_slice
    Slice(UInt8).new to_unsafe, 16
  end

  # Returns unsafe pointer to 16-bytes.
  def to_unsafe
    @bytes.to_unsafe
  end

  # Writes hyphenated format string to the *io*.
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
