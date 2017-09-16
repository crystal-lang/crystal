require "secure_random"

# Universally Unique IDentifier.
# Supports [RFC4122](https://www.ietf.org/rfc/rfc4122.txt) UUIDs and custom
struct UUID
  enum Variant # variants with 16 bytes.
    Unknown    # Unknown (ie. custom, your own).
    NCS        # Reserved by the NCS for backward compatibility.
    RFC4122    # Reserved for RFC4122 Specification (default).
    Microsoft  # Reserved by Microsoft for backward compatibility.
    Future     # Reserved for future expansion.
  end

  enum Version     # RFC4122 UUID versions.
    Unknown = 0 # Unknown version.
    V1 = 1      # date-time and MAC address.
    V2 = 2      # DCE security.
    V3 = 3      # MD5 hash and namespace.
    V4 = 4      # random.
    V5 = 5      # SHA1 hash and namespace.
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
    self.variant = Variant::RFC4122
    self.version = Version::V4
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
  def initialize(@bytes : StaticArray(UInt8, 16), variant : Variant, version : Version)
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
    # new StaticArray(UInt8, 16).new(0_u8)
    new(StaticArray(UInt8, 16).new(0_u8), UUID::Variant::NCS, UUID::Version::V4)
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

  # Same as `UUID#decode(value : String)`, returns `self`.
  def <<(value : String)
    decode value
    self
  end

  # Same as `UUID#variant=(value : Variant)`, returns `self`.
  def <<(value : Variant)
    variant = value
    self
  end

  # Same as `UUID#version=(value : Version)`, returns `self`.
  def <<(value : Version)
    version = value
    self
  end

  # Raises `ArgumentError` if string `value` at index `i` doesn't contain hex digit followed by another hex digit.
  def self.string_has_hex_pair_at!(value : String, i)
    unless value[i, 2].to_u8(16, whitespace: false, underscore: false, prefix: false)
      raise ArgumentError.new [
        "Invalid hex character at position #{i * 2} or #{i * 2 + 1}",
        "expected '0' to '9', 'a' to 'f' or 'A' to 'F'.",
      ].join(", ")
    end
  end

  # Creates new UUID by decoding `value` string from hyphenated (ie. `ba714f86-cac6-42c7-8956-bcf5105e1b81`),
  # hexstring (ie. `89370a4ab66440c8add39e06f2bb6af6`) or URN (ie. `urn:uuid:3f9eaf9e-cdb0-45cc-8ecb-0e5b2bfb0c20`)
  # format.
  def decode(value : String)
    case value.size
    when 36 # Hyphenated
      [8, 13, 18, 23].each do |offset|
        if value[offset] != '-'
          raise ArgumentError.new "Invalid UUID string format, expected hyphen at char #{offset}."
        end
      end
      [0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34].each_with_index do |offset, i|
        ::UUID.string_has_hex_pair_at! value, offset
        @bytes[i] = value[offset, 2].to_u8(16)
      end
    when 32 # Hexstring
      16.times do |i|
        ::UUID.string_has_hex_pair_at! value, i * 2
        @bytes[i] = value[i * 2, 2].to_u8(16)
      end
    when 45 # URN
      raise ArgumentError.new "Invalid URN UUID format, expected string starting with \":urn:uuid:\"." unless value.starts_with? "urn:uuid:"
      [9, 11, 13, 15, 18, 20, 23, 25, 28, 30, 33, 35, 37, 39, 41, 43].each_with_index do |offset, i|
        ::UUID.string_has_hex_pair_at! value, offset
        @bytes[i] = value[offset, 2].to_u8(16)
      end
    else
      raise ArgumentError.new "Invalid string length #{value.size} for UUID, expected 32 (hexstring), 36 (hyphenated) or 46 (urn)."
    end
  end

  def to_s
    slice = to_slice
    String.new(36) do |buffer|
      buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
      slice[0, 4].hexstring(buffer + 0)
      slice[4, 2].hexstring(buffer + 9)
      slice[6, 2].hexstring(buffer + 14)
      slice[8, 2].hexstring(buffer + 19)
      slice[10, 6].hexstring(buffer + 24)
      {36, 36}
    end
  end

  def hexstring
    to_slice.hexstring
  end

  def urn
    String.new(45) do |buffer|
      buffer.copy_from "urn:uuid:".to_unsafe, 9
      (buffer + 9).copy_from to_s.to_unsafe, 36
      {45, 45}
    end
  end

  {% for v in %w(1 2 3 4 5) %}

    # Returns `true` if UUID looks is a V{{ v.id }}, `false` otherwise.
    def v{{ v.id }}?
      variant == Variant::RFC4122 && version == RFC4122::Version::V{{ v.id }}
    end

    # Returns `true` if UUID looks is a V{{ v.id }}, raises `Error` otherwise.
    def v{{ v.id }}!
      unless v{{ v.id }}?
        raise Error.new("Invalid UUID variant #{variant} version #{version}, expected RFC 4122 V{{ v.id }}.")
      else
        true
      end
    end

  {% end %}
end
