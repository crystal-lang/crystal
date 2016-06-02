# Support for RFC 4122 UUID variant.
module UUID::RFC4122
  enum RFC4122Version
    Unknown
    V1
    V2
    V3
    V4
    V5
  end

  # Generates RFC UUID variant with specified format `version`.
  def initialize(version : RFC4122Version)
    case version
    when RFC4122Version::V4
      @data.to_unsafe.copy_from SecureRandom.random_bytes(16).to_unsafe, 16
      @data[6] = (@data[6] & 0x0f) | 0x40
      @data[8] = (@data[8] & 0x3f) | 0x80
    else
      raise ArgumentError.new "Unsupported version #{version}."
    end
  end

  {% for version in %w(1 2 3 4 5) %}

    def v{{ version.id }}?
      rfc4122_version == RFC4122Version::V{{ version.id }}
    end

    def v{{ version.id }}!
      unless v{{ version.id }}?
        raise Error.new("Invalid RFC 4122 UUID version #{rfc_4122}, expected V{{ version.id }}.")
      else
        true
      end
    end

  {% end %}
end
