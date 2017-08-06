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

  # Returns the short user name of the currently logged in user or `nil` if it
  # can't be determined. Note that this information is not secure.
  #
  # ```
  # System.login # => "myloginusername"
  # ```
  def self.login
    Crystal::System.login
  end
end
