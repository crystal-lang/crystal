require "crystal/system/user"

class System::User
  # Raised on user lookup failure.
  class NotFound < Exception
  end

  private getter sys_user : Crystal::System::User

  private def initialize(@sys_user)
  end

  # Returns the user associated with the given name, if it exists.
  #
  # Raises `Errno` if a system error occurs.
  def self.from_name?(name)
    sys_user = Crystal::System::User.from_name?(name)
    new(sys_user) if sys_user
  end

  # Returns the user associated with the given name.
  #
  # Raises `NotFound` if no such user exists.
  # See `from_name?`.
  def self.from_name(name)
    from_name?(name) || raise NotFound.new("No such user: #{name}")
  end

  # Returns the user associated with the given ID, if it exists.
  #
  # Raises `Errno` if a system error occurs.
  def self.from_id?(id)
    sys_user = Crystal::System::User.from_id?(id)
    new(sys_user) if sys_user
  end

  # Returns the user associated with the given ID.
  #
  # Raises `NotFound` if no such user exists.
  # See `from_name?`.
  def self.from_id(id)
    from_id?(id) || raise NotFound.new("No such user: #{id}")
  end

  # Returns the user's username.
  delegate name, to: @sys_user

  # Returns the user's password.
  delegate password, to: @sys_user

  # Returns the user's ID.
  delegate user_id, to: @sys_user

  # Returns the user's group ID.
  delegate group_id, to: @sys_user

  # Returns the user's home directory.
  delegate directory, to: @sys_user

  # Returns the user's shell.
  delegate shell, to: @sys_user
end
