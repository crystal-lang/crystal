require "crystal/system/user"

class System::User
  # Raised on user lookup failure.
  class NotFoundError < Exception
  end

  extend Crystal::System::User

  getter name : String
  getter user_id : LibC::UidT
  getter group_id : LibC::GidT
  getter directory : String
  getter shell : String

  def_equals_and_hash @user_id

  private def initialize(@name, @user_id, @group_id, @directory, @shell)
  end

  # Returns the user associated with the given name.
  #
  # Raises `NotFoundError` if no such user exists.
  # See `from_name?`.
  def self.from_name(name)
    from_name?(name) || raise NotFoundError.new("No such user: #{name}")
  end

  # Returns the user associated with the given ID.
  #
  # Raises `NotFoundError` if no such user exists.
  # See `from_name?`.
  def self.from_id(id)
    from_id?(id) || raise NotFoundError.new("No such user: #{id}")
  end

  def to_s(io)
    io << "#{name} (#{user_id})"
  end
end
