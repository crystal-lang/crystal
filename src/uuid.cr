require "secure_random"
require "./uuid/*"

# Universally Unique IDentifier.
#
# Supports custom variants with arbitrary 16 bytes as well as (RFC 4122)[https://www.ietf.org/rfc/rfc4122.txt] variant
# versions.
module UUID
  # Raises `ArgumentError` if string `value` at index `i` doesn't contain hex digit followed by another hex digit.
  # TODO: Move to String#digit?(...)
  def self.string_has_hex_pair_at!(value : String, i)
    unless value[i].hex? && value[i + 1].hex?
      raise ArgumentError.new [
        "Invalid hex character at position #{i * 2} or #{i * 2 + 1}",
        "expected '0' to '9', 'a' to 'f' or 'A' to 'F'.",
      ].join(", ")
    end
  end

  def self.new(*args)
    ::UUID::UUID.new *args
  end
end
