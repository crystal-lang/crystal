require "crystal/system/user"

class System::User
  # Raised on user lookup failure.
  class NotFoundError < Exception
  end

  extend Crystal::System::User

  getter username : String
  getter user_id : String
  getter group_id : String
  getter name : String
  getter directory : String
  getter shell : String

  def_equals_and_hash @user_id

  private def initialize(@username, @user_id, @group_id, @name, @directory, @shell)
  end

  # Returns the user associated with the given username.
  #
  # Raises `NotFoundError` if no such user exists.
  # See `from_name?`.
  def self.from_username(username)
    from_username?(username) || raise NotFoundError.new("No such user: #{username}")
  end

  # Returns the user associated with the given ID.
  #
  # Raises `NotFoundError` if no such user exists.
  # See `from_name?`.
  def self.from_id(id)
    from_id?(id) || raise NotFoundError.new("No such user: #{id}")
  end

  def to_s(io)
    io << "#{username} (#{user_id})"
  end
end
