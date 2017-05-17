# :nodoc:
module Crystal
  # :nodoc:
  module System
    # :nodoc:
    module Random
      # Fills *buffer* with random bytes from a secure source.
      # def self.random_bytes(buffer : Bytes) : Nil
    end
  end
end

{% if flag?(:linux) %}
  require "./unix/getrandom"
{% elsif flag?(:openbsd) %}
  require "./unix/arc4random"
{% else %}
  require "./unix/urandom"
{% end %}
