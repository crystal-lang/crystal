require "secure_random"

# Universally Unique IDentifier.
#
# Supports custom variants with arbitrary 16 bytes as well as (RFC 4122)[https://www.ietf.org/rfc/rfc4122.txt] variant
# versions.
struct UUID
  enum Variant # UUID variants.
    Unknown    # Unknown (ie. custom, your own).
    NCS        # Reserved by the NCS for backward compatibility.
    RFC4122    # As described in the RFC4122 Specification (default).
    Microsoft  # Reserved by Microsoft for backward compatibility.
    Future     # Reserved for future expansion.
  end

  # Generates a new `UUID` in the RFC 4122 v4 UUID format.
  # ```
  # uuid = UUID.new
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  ## TODO: should we set version?
  def initialize
    @bytes = SecureRandom.random_bytes(16).to_a
    self.variant = Variant::RFC4122
    self.version = 4_u8
  end

  # Generates a new `UUID` from a 16-`bytes` Array..
  # ```
  # arr = [0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8, 8_u8, 9_u8, 10_u8, 11_u8, 12_u8, 13_u8, 14_u8, 15_u8]
  # uuid = UUID.new(arr)
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  ## TODO: use instance_sizeof() to see if it can be coersed into UUID
  ## TODO: should we set version?
  def initialize(new_bytes : Array(UInt8))
    raise ArgumentError.new "Invalid bytes length #{new_bytes.size}, expected 16." if new_bytes.size != 16
    @bytes = new_bytes
    # self.variant = Variant::RFC4122
    # self.version = 4_u8
  end

  # Generates a new `UUID` from string `value`.
  # See `UUID#decode(value : String)` for details on supported string formats.
  # ```
  # value = "c20335c3-7f46-4126-aae9-f665434ad12b"
  # uuid = UUID.new(value)
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  def initialize(new_bytes : String)
    @bytes = Array(UInt8).new
    decode new_bytes
  end

  # Returns `true` if `other` string represents the same UUID, `false` otherwise.
  # ```
  # value1 = "c20335c3-7f46-4126-aae9-f665434ad12b"
  # value2 = "ee843b26-56d8-472b-b343-0b94ed9077ff"
  # uuid1  = UUID.new(value1)
  # uuid2  = UUID.new(value2)
  # uuid1 == uuid1.to_s # => true
  # uuid1 == uuid2.to_s # => false
  # ```
  def ==(other : String)
    self == UUID.new other
  end

  # Returns `true` if `other` static 16 bytes represent the same UUID, `false` otherwise.
  # ```
  # arr1  = [0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8, 8_u8, 9_u8, 10_u8, 11_u8, 12_u8, 13_u8, 14_u8, 15_u8]
  # arr2  = [15_u8, 14_u8, 13_u8, 12_u8, 11_u8, 10_u8, 9_u8, 8_u8, 7_u8, 6_u8, 5_u8, 4_u8, 3_u8, 2_u8, 1_u8, 0_u8]
  # uuid1 = UUID.new(arr1)
  # uuid2 = UUID.new(arr2)
  # uuid1 == uuid1.to_a # => true
  # uuid1 == uuid2.to_a # => false
  # ```
  def ==(other : Array(UInt8))
    self.to_a == other
  end

  # Returns the internal Representation of the UUID as an `Array(UInt8)`.
  # ```
  # arr  = [0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8, 8_u8, 9_u8, 10_u8, 11_u8, 12_u8, 13_u8, 14_u8, 15_u8]
  # uuid = UUID.new(arr)
  # uuid.to_a # => [0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8, 8_u8, 9_u8, 10_u8, 11_u8, 12_u8, 13_u8, 14_u8, 15_u8]
  # ```
  def to_a
    @bytes
  end

  # Writes a hyphenated format String to `io`.
  # See `UUID#encode(format : Symbol)` for details on String encoding.
  # ```
  # uuid = UUID.new
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  def to_s(io : IO)
    io << encode
  end

  # Writes a String to `io` with *args*.
  # See `UUID#encode(format : Symbol)` for details on String encoding.
  # ```
  # uuid = UUID.new
  # uuid.to_s(:hexstring) # => "c20335c37f464126aae9f665434ad12b"
  # ```
  def to_s(io : IO, format : Symbol)
    io << encode(format)
  end

  # Returns version based on RFC 4122 format. See also `UUID#variant`.
  # ```
  # uuid = UUID.new
  # uuid.version # => 4
  # ```
  def version
    @bytes[6] >> 4
  end

  # Sets version to a specified `value`.
  # Doesn't set variant (see `UUID#variant=(value : UInt8)`).
  # ```
  # uuid = UUID.new
  # uuid.version = 4_u8
  # uuid.version # => 4
  # ```
  def version=(version : UInt8)
    @bytes[6] = (@bytes[6] & 0xf) | (version << 4)
  end

  # Returns `UUID` variant.
  # Values for this are documented at `UUID#Variant`
  # ```
  # uuid = UUID.new
  # uuid.variant # => UUID::Variant::RFC4122
  # ```
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

  # Sets `UUID` variant to specified `variant`.
  # Values for this are documented at `UUID#Variant`
  # ```
  # uuid = UUID.new
  # uuid.variant = UUID::Variant::RFC4122
  # uuid.variant # => UUID::Variant::RFC4122
  # ```
  def variant=(variant : Variant)
    case variant
    when Variant::NCS
      @bytes[8] = @bytes[8] & 0x7f
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


  # Generates a `UUID` from a formatted `UUID` String.
  # See `UUID#encode(format : Symbol)` for details on String encoding.
  # ```
  # uuid1 = UUID.decode("c20335c3-7f46-4126-aae9-f665434ad12b")
  # uuid2 = UUID.decode("c20335c37f464126aae9f665434ad12b")
  # uuid3 = UUID.decode("urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b")
  # uuid1.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # uuid2.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # uuid3.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  def self.decode(value : String)
    value = value.delete("urn:uuid:") if value.starts_with? "urn:uuid:"
    value = value.delete('-') if [value[8], value[13], value[18], value[23]] == Array.new(4, '-')
    raise ArgumentError.new "Invalid UUID provided" if value.size != 32

    results = Array(UInt8).new
    char_iterator = value.each_char
    16.times do |index|
      char_pair = [char_iterator.next.to_s, char_iterator.next.to_s]
      # raise ArgumentError.new "Invalid UUID char format" unless char_pair.all?(&.hex?)
      results << char_pair.join.to_u8(16)
    end

    new(results)
  end

  # Generates a `UUID` from a formatted `UUID` String.
  # See `UUID#encode(format : Symbol)` for details on String encoding.
  # Hyphenated Format
  # ```
  # uuid = UUID.new
  # uuid.to_s # => "ee843b26-56d8-472b-b343-0b94ed9077ff"
  # uuid.decode("c20335c3-7f46-4126-aae9-f665434ad12b")
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  # Hexstring Format
  # ```
  # uuid = UUID.new
  # uuid.to_s # => "ee843b26-56d8-472b-b343-0b94ed9077ff"
  # uuid.decode("c20335c37f464126aae9f665434ad12b")
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  # URN Format
  # ```
  # uuid = UUID.new
  # uuid.to_s # => "ee843b26-56d8-472b-b343-0b94ed9077ff"
  # uuid.decode("urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b")
  # uuid.to_s # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  def decode(value : String)
    value = value[0..8] if value.starts_with? "urn:uuid:"
    value = value.delete('-') if [value[8], value[13], value[18], value[23]] == Array.new(4, '-')
    raise ArgumentError.new "Invalid UUID provided" if value.size != 32

    # value.each_char.each_combination(2) do |pair|
      # raise ArgumentError.new "Invalid UUID char format" unless char_pair.all?(&.hex?)
      value.each_char do |char|
        @bytes << char.to_i(16).to_u8
      end
    # end

    @bytes
  end

  # Generates a String representing a `UUID`
  # Hyphenated Format contains '-' between after the 2nd, 3rd, 4th, 5th byte
  # ```
  # uuid = UUID.new
  # uuid.encode              # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # uuid.encode(:hyphenated) # => "c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  # Hexstring Format is a 32 character String of "0-9" or "a-z" or "A-Z"
  # ```
  # uuid = UUID.new
  # uuid.encode(:hexstring)  # => "c20335c37f464126aae9f665434ad12b"
  # ```
  # URN Format begins with `"urn:uuid:"` and then a Hyphonated Fromat String
  # ```
  # uuid = UUID.new
  # uuid.encode(:urn)        # => "urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b"
  # ```
  def encode(format = :hyphenated)
    case format
    when :hyphenated
      "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % @bytes
    when :hexstring
      "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x" % @bytes
    when :urn
      "urn:uuid:%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % @bytes
    else
      raise ArgumentError.new "Unexpected format #{format}."
    end
  end
end
