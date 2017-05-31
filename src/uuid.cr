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
    bytes = StaticArray(UInt8, 16).new(0_u8)
    bytes.to_unsafe.copy_from SecureRandom.random_bytes(16).pointer(16), 16
    initialize bytes
  end

  # Creates UUID from 16-`bytes` slice.
  def initialize(slice : Slice(UInt8))
    if slice.size != 16
      raise ArgumentError.new "Invalid bytes length #{@bytes.size}, expected 16."
    end
    @bytes = uninitialized UInt8[16]
    @bytes.to_unsafe.copy_from slice
  end

  # Generates UUID from static 16-`bytes`.
  def initialize(@bytes : StaticArray(UInt8, 16))
    initialize @bytes, Version::V4
  end

  # Creates UUID from string `value`. See `UUID#decode(value : String)` for details on supported string formats.
  def initialize(value : String)
    @bytes = uninitialized UInt8[16]
    decode value
  end

  # Generates RFC 4122 UUID `variant` with specified `version`.
  def initialize(@bytes : StaticArray(UInt8, 16), version = Version::V4)
    #@bytes.to_unsafe.copy_from SecureRandom.random_bytes(16).pointer(16), 16

    case version
    when Version::V4
      variant = Variant::RFC4122
      version = Version::V4
    else
      raise ArgumentError.new "Creating #{version} not supported."
    end
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
