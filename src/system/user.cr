require "crystal/system/user"

# Represents a user on the host system.
#
# NOTE: To use User, you must explicitly import it with `require "system/user"`
#
# Users can be retrieved by either username or their user ID:
#
# ```
# require "system/user"
#
# System::User.find_by name: "root"
# System::User.find_by id: "0"
# ```
class System::User
  # Raised on user lookup failure.
  class NotFoundError < Exception
  end

  include Crystal::System::User

  # The user's username.
  def username : String
    system_username
  end

  # The user's identifier.
  def id : String
    system_id
  end

  # The user's primary group identifier.
  def group_id : String
    system_group_id
  end

  # The user's real or full name.
  #
  # May not be present on all platforms. Returns the same value as `#username`
  # if neither a real nor full name is available.
  def name : String
    system_name
  end

  # The user's home directory.
  def home_directory : String
    system_home_directory
  end

  # The user's login shell.
  def shell : String
    system_shell
  end

  def_equals_and_hash id

  # Returns the user associated with the given username.
  #
  # Raises `NotFoundError` if no such user exists.
  def self.find_by(*, name : String) : System::User
    find_by?(name: name) || raise NotFoundError.new("No such user: #{name}")
  end

  # Returns the user associated with the given username.
  #
  # Returns `nil` if no such user exists.
  def self.find_by?(*, name : String) : System::User?
    Crystal::System::User.from_username?(name)
  end

  # Returns the user associated with the given ID.
  #
  # Raises `NotFoundError` if no such user exists.
  def self.find_by(*, id : String) : System::User
    find_by?(id: id) || raise NotFoundError.new("No such user: #{id}")
  end

  # Returns the user associated with the given ID.
  #
  # Returns `nil` if no such user exists.
  def self.find_by?(*, id : String) : System::User?
    Crystal::System::User.from_id?(id)
  end

  def to_s(io)
    io << username << " (" << id << ')'
  end
end
