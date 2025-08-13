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

{% if flag?(:wasi) %}
  require "./wasi/random"
{% elsif flag?(:linux) %}
  require "c/sys/random"
  \{% if LibC.has_method?(:getrandom) %}
    require "./unix/getrandom"
  \{% else %}
    require "./unix/urandom"
  \{% end %}
{% elsif flag?(:bsd) || flag?(:darwin) %}
  require "./unix/arc4random"
{% elsif flag?(:unix) %}
  require "./unix/urandom"
{% elsif flag?(:win32) %}
  require "./win32/random"
{% else %}
  {% raise "No Crystal::System::Random implementation available" %}
{% end %}
