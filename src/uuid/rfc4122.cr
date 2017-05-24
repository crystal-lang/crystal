# Support for RFC 4122 UUID variant.
struct UUID
  # RFC 4122 UUID variant versions.
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

  # Generates RFC 4122 UUID `variant` with specified `version`.
  def initialize(version : Version)
    case version
    when Version::V4
      @bytes.to_unsafe.copy_from SecureRandom.random_bytes(16).pointer(16), 16
      variant = Variant::RFC4122
      version = Version::V4
    else
      raise ArgumentError.new "Creating #{version} not supported."
    end
  end

  # Returns version based on provided 6th `byte` (0-indexed).
  def self.byte_version(byte : UInt8)
    case byte >> 4
    when 1 then Version::V1
    when 2 then Version::V2
    when 3 then Version::V3
    when 4 then Version::V4
    when 5 then Version::V5
    else        Version::Unknown
    end
  end

  # Returns byte with encoded `version` for provided 6th `byte` (0-indexed) for known versions.
  # For `Version::Unknown` `version` raises `ArgumentError`.
  def self.byte_version(byte : UInt8, version : Version) : UInt8
    if version != Version::Unknown
      (byte & 0xf) | (version.to_u8 << 4)
    else
      raise ArgumentError.new "Can't set unknown version."
    end
  end

  # Returns version based on RFC 4122 format. See also `UUID#variant`.
  def version
    UUID.byte_version @bytes[6]
  end

  # Sets Version to a specified `value`. Doesn't set variant (see `UUID#variant=(value : Variant)`).
  def version=(value : Version)
    @bytes[6] = UUID.byte_version @bytes[6], value
  end

  {% for v in %w(1 2 3 4 5) %}

    # Returns `true` if UUID looks is a Vx, `false` otherwise.
    def v{{ v.id }}?
      variant == Variant::RFC4122 && version == RFC4122::Version::V{{ v.id }}
    end

    # Returns `true` if UUID looks is a Vx, raises `Error` otherwise.
    def v{{ v.id }}!
      unless v{{ v.id }}?
        raise Error.new("Invalid UUID variant #{variant} version #{version}, expected RFC 4122 V{{ v.id }}.")
      else
        true
      end
    end

  {% end %}
end
