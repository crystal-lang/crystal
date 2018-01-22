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

  # Returns the user specified by the user name or ID.
  # Raises `System::User::NotFoundError` if not found.
  # ```
  # System.user(0)
  # System.user("root")
  # ```
  def self.user(name : String | Int) : User
    User.get(name)
  end

  # Returns the user specified by the user name or ID.
  # Returns `nil` if not found.
  # ```
  # System.user?(0)
  # System.user?("root")
  # ```
  def self.user?(name : String | Int) : User?
    User.get?(name)
  end

  # Returns the group specified by the group name or ID.
  # Raises `System::Group::NotFoundError` if not found.
  # ```
  # System.group(0)
  # System.group("wheel")
  # ```
  def self.group(name : String | Int) : Group
    Group.get(name)
  end

  # Returns the group specified by the group name or ID.
  # Returns `nil` if not found.
  # ```
  # System.group?(0)
  # System.group?("wheel")
  # ```
  def self.group?(name : String | Int) : Group?
    Group.get?(name)
  end
end
