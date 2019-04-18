# Represents a UUID (Universally Unique IDentifier).
struct UUID
  # Variants with 16 bytes.
  enum Variant
    # Unknown (i.e. custom, your own).
    Unknown
    # Reserved by the NCS for backward compatibility.
    NCS
    # Reserved for RFC4122 Specification (default).
    RFC4122
    # Reserved by Microsoft for backward compatibility.
    Microsoft
    # Reserved for future expansion.
    Future
  end

  # RFC4122 UUID versions.
  enum Version
    # Unknown version.
    Unknown = 0
    # Date-time and MAC address.
    V1 = 1
    # DCE security.
    V2 = 2
    # MD5 hash and namespace.
    V3 = 3
    # Random.
    V4 = 4
    # SHA1 hash and namespace.
    V5 = 5
  end

  protected getter bytes : StaticArray(UInt8, 16)

  # Generates UUID from *bytes*, applying *version* and *variant* to the UUID if
  # present.
  def initialize(@bytes : StaticArray(UInt8, 16), variant : UUID::Variant? = nil, version : UUID::Version? = nil)
    case variant
    when nil
      # do nothing
    when Variant::NCS
      @bytes[8] = (@bytes[8] & 0x7f)
    when Variant::RFC4122
      @bytes[8] = (@bytes[8] & 0x3f) | 0x80
    when Variant::Microsoft
      @bytes[8] = (@bytes[8] & 0x1f) | 0xc0
    when Variant::Future
      @bytes[8] = (@bytes[8] & 0x1f) | 0xe0
    else
      raise ArgumentError.new "Can't set unknown variant"
    end

    if version
      raise ArgumentError.new "Can't set unknown version" if version.unknown?
      @bytes[6] = (@bytes[6] & 0xf) | (version.to_u8 << 4)
    end
  end

  # Creates UUID from 16-bytes slice. Raises if *slice* isn't 16 bytes long. See
  # `#initialize` for *variant* and *version*.
  def self.new(slice : Slice(UInt8), variant = nil, version = nil)
    raise ArgumentError.new "Invalid bytes length #{slice.size}, expected 16" unless slice.size == 16

    bytes = uninitialized UInt8[16]
    slice.copy_to(bytes.to_slice)

    new(bytes, variant, version)
  end

  # Creates another `UUID` which is a copy of *uuid*, but allows overriding
  # *variant* or *version*.
  def self.new(uuid : UUID, variant = nil, version = nil)
    new(uuid.bytes, variant, version)
  end

  # Creates new UUID by decoding `value` string from hyphenated (ie. `ba714f86-cac6-42c7-8956-bcf5105e1b81`),
  # hexstring (ie. `89370a4ab66440c8add39e06f2bb6af6`) or URN (ie. `urn:uuid:3f9eaf9e-cdb0-45cc-8ecb-0e5b2bfb0c20`)
  # format.
  def self.new(value : String, variant = nil, version = nil)
    bytes = uninitialized UInt8[16]

    case value.size
    when 36 # Hyphenated
      {8, 13, 18, 23}.each do |offset|
        if value[offset] != '-'
          raise ArgumentError.new "Invalid UUID string format, expected hyphen at char #{offset}"
        end
      end
      {0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34}.each_with_index do |offset, i|
        bytes[i] = hex_pair_at value, offset
      end
    when 32 # Hexstring
      16.times do |i|
        bytes[i] = hex_pair_at value, i * 2
      end
    when 45 # URN
      raise ArgumentError.new "Invalid URN UUID format, expected string starting with \"urn:uuid:\"" unless value.starts_with? "urn:uuid:"
      {9, 11, 13, 15, 18, 20, 23, 25, 28, 30, 33, 35, 37, 39, 41, 43}.each_with_index do |offset, i|
        bytes[i] = hex_pair_at value, offset
      end
    else
      raise ArgumentError.new "Invalid string length #{value.size} for UUID, expected 32 (hexstring), 36 (hyphenated) or 45 (urn)"
    end

    new(bytes, variant, version)
  end

  # Raises `ArgumentError` if string `value` at index `i` doesn't contain hex
  # digit followed by another hex digit.
  private def self.hex_pair_at(value : String, i) : UInt8
    if (ch1 = value[i].to_u8?(16)) && (ch2 = value[i + 1].to_u8?(16))
      ch1 * 16 + ch2
    else
      raise ArgumentError.new [
        "Invalid hex character at position #{i * 2} or #{i * 2 + 1}",
        "expected '0' to '9', 'a' to 'f' or 'A' to 'F'",
      ].join(", ")
    end
  end

  # Generates RFC 4122 v4 UUID.
  #
  # It is strongly recommended to use a cryptographically random source for
  # *random*, such as `Random::Secure`.
  def self.random(random = Random::Secure, variant = Variant::RFC4122, version = Version::V4)
    new_bytes = uninitialized UInt8[16]
    random.random_bytes(new_bytes.to_slice)

    new(new_bytes, variant, version)
  end

  def self.empty
    new(StaticArray(UInt8, 16).new(0_u8), UUID::Variant::NCS, UUID::Version::V4)
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

  # Returns 16-byte slice.
  def to_slice
    @bytes.to_slice
  end

  # Returns unsafe pointer to 16-bytes.
  def to_unsafe
    @bytes.to_unsafe
  end

  # Returns `true` if `other` UUID represents the same UUID, `false` otherwise.
  def ==(other : UUID)
    to_slice == other.to_slice
  end

  # Convert to `String` in literal format.
  def inspect(io : IO) : Nil
    io << "UUID("
    to_s(io)
    io << ')'
  end

  def to_s(io : IO) : Nil
    slice = to_slice

    buffer = uninitialized UInt8[36]
    buffer_ptr = buffer.to_unsafe

    buffer_ptr[8] = buffer_ptr[13] = buffer_ptr[18] = buffer_ptr[23] = '-'.ord.to_u8
    slice[0, 4].hexstring(buffer_ptr + 0)
    slice[4, 2].hexstring(buffer_ptr + 9)
    slice[6, 2].hexstring(buffer_ptr + 14)
    slice[8, 2].hexstring(buffer_ptr + 19)
    slice[10, 6].hexstring(buffer_ptr + 24)

    io.write(buffer.to_slice)
  end

  def hexstring
    to_slice.hexstring
  end

  def urn
    String.build(45) do |str|
      str << "urn:uuid:"
      to_s(str)
    end
  end

  class Error < Exception
  end

  {% for v in %w(1 2 3 4 5) %}
    # Returns `true` if UUID is a V{{ v.id }}, `false` otherwise.
    def v{{ v.id }}?
      variant == Variant::RFC4122 && version == Version::V{{ v.id }}
    end

    # Returns `true` if UUID is a V{{ v.id }}, raises `Error` otherwise.
    def v{{ v.id }}!
      unless v{{ v.id }}?
        raise Error.new("Invalid UUID variant #{variant} version #{version}, expected RFC 4122 V{{ v.id }}")
      else
        true
      end
    end
  {% end %}
end
