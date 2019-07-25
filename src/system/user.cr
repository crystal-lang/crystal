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
  def self.find_by(*, name)
    find_by?(name: name) || raise NotFoundError.new("No such user: #{name}")
  end

  # Returns the user associated with the given username.
  #
  # Returns `nil` if no such user exists.
  def self.find_by?(*, name)
    from_username?(name)
  end

  # Returns the user associated with the given ID.
  #
  # Raises `NotFoundError` if no such user exists.
  def self.find_by(*, id)
    find_by?(id: id) || raise NotFoundError.new("No such user: #{id}")
  end

  # Returns the user associated with the given ID.
  #
  # Returns `nil` if no such user exists.
  def self.find_by?(*, id)
    from_id?(id)
  end

  def to_s(io)
    io << "#{username} (#{user_id})"
  end
end
