# Represents a UUID (Universally Unique IDentifier).
#
# NOTE: To use `UUID`, you must explicitly import it with `require "uuid"`
struct UUID
  include Comparable(UUID)

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

  @bytes : StaticArray(UInt8, 16)

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
  def self.new(slice : Slice(UInt8), variant : Variant? = nil, version : Version? = nil)
    raise ArgumentError.new "Invalid bytes length #{slice.size}, expected 16" unless slice.size == 16

    bytes = uninitialized UInt8[16]
    slice.copy_to(bytes.to_slice)

    new(bytes, variant, version)
  end

  # Creates another `UUID` which is a copy of *uuid*, but allows overriding
  # *variant* or *version*.
  def self.new(uuid : UUID, variant : Variant? = nil, version : Version? = nil)
    new(uuid.bytes, variant, version)
  end

  # Creates new UUID by decoding `value` string from hyphenated (ie `ba714f86-cac6-42c7-8956-bcf5105e1b81`),
  # hexstring (ie `89370a4ab66440c8add39e06f2bb6af6`) or URN (ie `urn:uuid:3f9eaf9e-cdb0-45cc-8ecb-0e5b2bfb0c20`)
  # format, raising an `ArgumentError` if the string does not match any of these formats.
  def self.new(value : String, variant : Variant? = nil, version : Version? = nil)
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

  # Creates new UUID by decoding `value` string from hyphenated (ie `ba714f86-cac6-42c7-8956-bcf5105e1b81`),
  # hexstring (ie `89370a4ab66440c8add39e06f2bb6af6`) or URN (ie `urn:uuid:3f9eaf9e-cdb0-45cc-8ecb-0e5b2bfb0c20`)
  # format, returning `nil` if the string does not match any of these formats.
  def self.parse?(value : String, variant : Variant? = nil, version : Version? = nil) : UUID?
    bytes = uninitialized UInt8[16]

    case value.size
    when 36 # Hyphenated
      {8, 13, 18, 23}.each do |offset|
        return if value[offset] != '-'
      end
      {0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34}.each_with_index do |offset, i|
        if hex = hex_pair_at? value, offset
          bytes[i] = hex
        else
          return
        end
      end
    when 32 # Hexstring
      16.times do |i|
        if hex = hex_pair_at? value, i * 2
          bytes[i] = hex
        else
          return
        end
      end
    when 45 # URN
      return unless value.starts_with? "urn:uuid:"
      {9, 11, 13, 15, 18, 20, 23, 25, 28, 30, 33, 35, 37, 39, 41, 43}.each_with_index do |offset, i|
        if hex = hex_pair_at? value, offset
          bytes[i] = hex
        else
          return
        end
      end
    else
      return
    end

    new(bytes, variant, version)
  end

  # Raises `ArgumentError` if string `value` at index `i` doesn't contain hex
  # digit followed by another hex digit.
  private def self.hex_pair_at(value : String, i) : UInt8
    hex_pair_at?(value, i) || raise ArgumentError.new "Invalid hex character at position #{i * 2} or #{i * 2 + 1}, expected '0' to '9', 'a' to 'f' or 'A' to 'F'"
  end

  # Parses 2 hex digits from `value` at index `i` and `i + 1`, returning `nil`
  # if one or both are not actually hex digits.
  private def self.hex_pair_at?(value : String, i) : UInt8?
    if (ch1 = value[i].to_u8?(16)) && (ch2 = value[i + 1].to_u8?(16))
      ch1 * 16 + ch2
    end
  end

  # Generates RFC 4122 v4 UUID.
  #
  # It is strongly recommended to use a cryptographically random source for
  # *random*, such as `Random::Secure`.
  def self.random(random : Random = Random::Secure, variant : Variant = :rfc4122, version : Version = :v4) : self
    new_bytes = uninitialized UInt8[16]
    random.random_bytes(new_bytes.to_slice)

    new(new_bytes, variant, version)
  end

  # Generates an empty UUID.
  #
  # ```
  # UUID.empty # => UUID(00000000-0000-4000-0000-000000000000)
  # ```
  def self.empty : self
    new(StaticArray(UInt8, 16).new(0_u8), UUID::Variant::NCS, UUID::Version::V4)
  end

  # Returns UUID variant based on the [RFC4122 format](https://datatracker.ietf.org/doc/html/rfc4122#section-4.1).
  # See also `#version`
  #
  # ```
  # require "uuid"
  #
  # UUID.new(Slice.new(16, 0_u8), variant: UUID::Variant::NCS).variant       # => UUID::Variant::NCS
  # UUID.new(Slice.new(16, 0_u8), variant: UUID::Variant::RFC4122).variant   # => UUID::Variant::RFC4122
  # UUID.new(Slice.new(16, 0_u8), variant: UUID::Variant::Microsoft).variant # => UUID::Variant::Microsoft
  # UUID.new(Slice.new(16, 0_u8), variant: UUID::Variant::Future).variant    # => UUID::Variant::Future
  # ```
  def variant : UUID::Variant
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

  # Returns version based on [RFC4122 format](https://datatracker.ietf.org/doc/html/rfc4122#section-4.1).
  # See also `#variant`.
  #
  # ```
  # require "uuid"
  #
  # UUID.new(Slice.new(16, 0_u8), version: UUID::Version::V1).version # => UUID::Version::V1
  # UUID.new(Slice.new(16, 0_u8), version: UUID::Version::V2).version # => UUID::Version::V2
  # UUID.new(Slice.new(16, 0_u8), version: UUID::Version::V3).version # => UUID::Version::V3
  # UUID.new(Slice.new(16, 0_u8), version: UUID::Version::V4).version # => UUID::Version::V4
  # UUID.new(Slice.new(16, 0_u8), version: UUID::Version::V5).version # => UUID::Version::V5
  # ```
  def version : UUID::Version
    case @bytes[6] >> 4
    when 1 then Version::V1
    when 2 then Version::V2
    when 3 then Version::V3
    when 4 then Version::V4
    when 5 then Version::V5
    else        Version::Unknown
    end
  end

  # Returns the binary representation of the UUID.
  def bytes : StaticArray(UInt8, 16)
    @bytes.dup
  end

  # Returns unsafe pointer to 16-bytes.
  def to_unsafe
    @bytes.to_unsafe
  end

  def_equals_and_hash @bytes

  # Convert to `String` in literal format.
  def inspect(io : IO) : Nil
    io << "UUID("
    to_s(io)
    io << ')'
  end

  def to_s(io : IO) : Nil
    slice = @bytes.to_slice

    buffer = uninitialized UInt8[36]
    buffer_ptr = buffer.to_unsafe

    buffer_ptr[8] = buffer_ptr[13] = buffer_ptr[18] = buffer_ptr[23] = '-'.ord.to_u8
    slice[0, 4].hexstring(buffer_ptr + 0)
    slice[4, 2].hexstring(buffer_ptr + 9)
    slice[6, 2].hexstring(buffer_ptr + 14)
    slice[8, 2].hexstring(buffer_ptr + 19)
    slice[10, 6].hexstring(buffer_ptr + 24)

    io.write_string(buffer.to_slice)
  end

  def hexstring : String
    @bytes.to_slice.hexstring
  end

  # Returns a `String` that is a valid urn of *self*
  #
  # ```
  # require "uuid"
  #
  # uuid = UUID.empty
  # uuid.urn # => "urn:uuid:00000000-0000-4000-0000-000000000000"
  # uuid2 = UUID.new("c49fc136-9362-4414-81a5-9a7e0fcca0f1")
  # uuid2.urn # => "urn:uuid:c49fc136-9362-4414-81a5-9a7e0fcca0f1"
  # ```
  def urn : String
    String.build(45) do |str|
      str << "urn:uuid:"
      to_s(str)
    end
  end

  def <=>(other : UUID) : Int32
    @bytes <=> other.bytes
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
