require "crystal/system"

module System
  # Returns the hostname.
  #
  # NOTE: Maximum of 253 characters are allowed, with 2 bytes reserved for
  # storage.
  # In practice, many platforms will disallow anything longer than 63 characters.
  #
  # ```
  # System.hostname # => "host.example.org"
  # ```
  def self.hostname
    Crystal::System.hostname
  end

  # Returns the number of logical processors available to the system.
  #
  # ```
  # System.cpu_count # => 4
  # ```
  def self.cpu_count
    Crystal::System.cpu_count
  end
end
