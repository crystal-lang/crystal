module Crystal::System::Random
  # Fills *buffer* with random bytes from a secure source.
  # def self.random_bytes(buffer : Bytes) : Nil

  # Returns a random unsigned integer from a secure source. Implementations
  # may choose the integer size to return based on what the system source
  # provides. They may choose to return a single byte (UInt8) in which case
  # `::Random` will prefer `#random_bytes` to read as many bytes as required
  # at once, avoiding multiple reads or reading too many bytes.
  # def self.next_u
end

{% if flag?(:linux) %}
  require "./unix/getrandom"
{% elsif flag?(:openbsd) %}
  require "./unix/arc4random"
{% else %}
  # TODO: restrict on flag?(:unix) after crystal > 0.22.0 is released
  require "./unix/urandom"
{% end %}
