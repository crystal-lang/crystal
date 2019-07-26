require "crystal/system/group"

class System::Group
  # Raised on group lookup failure.
  class NotFoundError < Exception
  end

  extend Crystal::System::Group

  # The group's name.
  getter name : String

  # The group's identifier.
  getter id : String

  # The group's usernames.
  getter members : Array(String)

  def_equals_and_hash @id

  private def initialize(@name, @id, @members)
  end

  # Returns the group associated with the given name.
  #
  # Raises `NotFoundError` if no such group exists.
  def self.find_by(*, name)
    find_by?(name: name) || raise NotFoundError.new("No such group: #{name}")
  end

  # Returns the group associated with the given name.
  #
  # Returns `nil` if no such group exists.
  def self.find_by?(*, name)
    from_name?(name)
  end

  # Returns the group associated with the given ID.
  #
  # Raises `NotFoundError` if no such group exists.
  def self.find_by(*, id)
    find_by?(id: id) || raise NotFoundError.new("No such group: #{id}")
  end

  # Returns the group associated with the given ID.
  #
  # Returns `nil` if no such group exists.
  def self.find_by?(*, id)
    from_id?(id)
  end

  def to_s(io)
    io << "#{name} (#{id})"
  end
end
