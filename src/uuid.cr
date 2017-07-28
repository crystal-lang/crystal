require "secure_random"
require "./uuid/*"

# Universally Unique IDentifier.
#
# Supports [RFC4122](https://www.ietf.org/rfc/rfc4122.txt) UUIDs and custom
# variants with arbitrary 16 bytes.
struct UUID
  enum Variant
    # Unknown (ie. custom, your own).
    Unknown

    # Reserved by the NCS for backward compatibility.
    NCS

    # As described in the RFC4122 Specification (default).
    RFC4122

    # Reserved by Microsoft for backward compatibility.
    Microsoft

    # Reserved for future expansion.
    Future
  end

  # RFC4122 UUID variant versions.
  enum Version
    # Unknown version.
    Unknown = 0

    # Version 1 - date-time and MAC address.
    V1 = 1

    # Version 2 - DCE security.
    V2 = 2

    # Version 3 - MD5 hash and namespace.
    V3 = 3

    # Version 4 - random.
    V4 = 4

    # Version 5 - SHA1 hash and namespace.
    V5 = 5
  end


  # Internal representation.
  @bytes : StaticArray(UInt8, 16)

  # Generates RFC 4122 v4 UUID.
  def initialize
    @bytes = uninitialized UInt8[16]
    @bytes.to_unsafe.copy_from SecureRandom.random_bytes(16).pointer(16), 16

    variant = Variant::RFC4122
    version = Version::V4
  end

  # Creates UUID from 16-bytes slice.
  def initialize(slice : Slice(UInt8))
    raise ArgumentError.new "Invalid bytes length #{@bytes.size}, expected 16." unless slice.size == 16

    @bytes = uninitialized UInt8[16]
    @bytes.to_unsafe.copy_from(slice)

    variant = Variant::RFC4122
    version = Version::V4
  end

  # Generates UUID from static 16-`bytes`.
  def initialize(@bytes : StaticArray(UInt8, 16))
    variant = Variant::RFC4122
    version = Version::V4
  end

  # Creates UUID from string `value`. See `UUID#decode(value : String)` for details on supported string formats.
  def initialize(value : String)
    @bytes = uninitialized UInt8[16]
    decode value
  end

  def initialize(version : Version)
    @bytes = uninitialized UInt8[16]
    @bytes.to_unsafe.copy_from SecureRandom.random_bytes(16).pointer(16), 16

    variant = Variant::RFC4122
    version = version
  end

  # Creates UUID from bytes, applying *version* and *variant* to the UUID.
  def initialize(@bytes, variant : Variant, version : Version)
    self.variant = variant
    self.version = version
  end


  def initialize(variant : Variant)
    @bytes = uninitialized UInt8[16]
    @bytes.to_unsafe.copy_from SecureRandom.random_bytes(16).pointer(16), 16

    variant = variant
    version = Version::V4
  end

  # Generates RFC 4122 UUID `variant` with specified `version`.
  def initialize(@bytes : StaticArray(UInt8, 16), version = Version::V4)
    case version
    when Version::V4
      variant = Variant::RFC4122
      version = Version::V4
    else
      raise ArgumentError.new "Creating #{version} not supported."
    end
  end

  # Returns UUID variant.
  def variant
    case
    when @bytes[8] & 0x80 == 0x00
      Variant::NCS
    when @bytes[8] & 0xc0 == 0x80
      Variant::RFC4122
    when @bytes[8] & 0xe0 == 0xc0
      Variant::Microsoft
    when @bytes[8] & 0xe0 == 0xe0
      Variant::Future
    else
      Variant::Unknown
    end
  end

  # Sets UUID variant to specified *value*.
  def variant=(value : Variant)
    case value
    when Variant::NCS
      @bytes[8] = (@bytes[8] & 0x7f)
    when Variant::RFC4122
      @bytes[8] = (@bytes[8] & 0x3f) | 0x80
    when Variant::Microsoft
      @bytes[8] = (@bytes[8] & 0x1f) | 0xc0
    when Variant::Future
      @bytes[8] = (@bytes[8] & 0x1f) | 0xe0
    else
      raise ArgumentError.new "Can't set unknown variant."
    end
  end

  # Returns version based on RFC4122 format. See also `#variant`.
  def version
    case @bytes[6] >> 4
    when 1 then Version::V1
    when 2 then Version::V2
    when 3 then Version::V3
    when 4 then Version::V4
    when 5 then Version::V5
    else        Version::Unknown
    end
  end

  # Sets `version`. Doesn't set variant (see `#variant=`).
  def version=(value : Version)
    raise ArgumentError.new "Can't set unknown version." if value.unknown?
    @bytes[6] = (@bytes[6] & 0xf) | (value.to_u8 << 4)
  end

  def self.empty
    new StaticArray(UInt8, 16).new(0_u8)
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
