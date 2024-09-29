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
  def self.hostname : String
    Crystal::System.hostname
  end

  # Returns the number of logical processors available to the system.
  #
  # ```
  # System.cpu_count # => 4
  # ```
  def self.cpu_count : Int
    Crystal::System.cpu_count
  end

  # Returns the soft and hard file descriptor limits for the current process
  #
  # ```
  # System.file_descriptor_limit # => { 1024, 524288 }
  # ```
  def self.file_descriptor_limit
    Crystal::System.file_descriptor_limit
  end

  # Sets the soft file descriptor limits for the current process
  #
  # ```
  # System.file_descriptor_limit = 4096
  # ```
  def self.file_descriptor_limit=(limit : UInt32)
    Crystal::System.file_descriptor_limit = limit
  end
end
