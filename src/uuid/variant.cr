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
end
