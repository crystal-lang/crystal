require "c/unistd"

module System
  # Returns the hostname.
  #
  # NOTE: Maximum of 253 characters are allowed, with 2 bytes reserved for storage.
  # In practice, many platforms will disallow anything longer than 63 characters.
  #
  # ```
  # System.hostname # => "host.example.org"
  # ```
  def self.hostname
    String.new(255) do |buffer|
      unless LibC.gethostname(buffer, LibC::SizeT.new(255)) == 0
        raise Errno.new("Could not get hostname")
      end
      len = LibC.strlen(buffer)
      {len, len}
    end
  end
end
