struct UUID
  # UUID variants.
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

  # Returns UUID variant based on provided 8th `byte` (0-indexed).
  def self.byte_variant(byte : UInt8)
    case
    when byte & 0x80 == 0x00
      Variant::NCS
    when byte & 0xc0 == 0x80
      Variant::RFC4122
    when byte & 0xe0 == 0xc0
      Variant::Microsoft
    when byte & 0xe0 == 0xe0
      Variant::Future
    else
      Variant::Unknown
    end
  end

  # Returns byte with encoded `variant` based on provided 8th `byte` (0-indexed) for known variants.
  # For `Variant::Unknown` `variant` raises `ArgumentError`.
  def self.byte_variant(byte : UInt8, variant : Variant) : UInt8
    case variant
    when Variant::NCS
      byte & 0x7f
    when Variant::RFC4122
      (byte & 0x3f) | 0x80
    when Variant::Microsoft
      (byte & 0x1f) | 0xc0
    when Variant::Future
      (byte & 0x1f) | 0xe0
    else
      raise ArgumentError.new "Can't set unknown variant."
    end
  end

  # Returns UUID variant.
  def variant
    UUID.byte_variant @bytes[8]
  end

  # Sets UUID variant to specified *value*.
  def variant=(value : Variant)
    @bytes[8] = UUID.byte_variant @bytes[8], value
  end
end
