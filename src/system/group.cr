require "crystal/system/group"

class System::Group
  # Raised on group lookup failure.
  class NotFoundError < Exception
  end

  extend Crystal::System::Group

  getter name : String
  getter id : LibC::GidT
  getter members : Array(String)

  def_equals_and_hash @id

  private def initialize(@name, @id, @members)
  end

  # Returns the group associated with the given name.
  #
  # Raises `NotFoundError` if no such group exists.
  # See `from_name?`.
  def self.from_name(name)
    from_name?(name) || raise NotFoundError.new("No such group: #{name}")
  end

  # Returns the group associated with the given ID.
  #
  # Raises `NotFoundError` if no such group exists.
  # See `from_id?`.
  def self.from_id(id)
    from_id?(id) || raise NotFoundError.new("No such group: #{id}")
  end

  def to_s(io)
    io << "#{name} (#{id})"
  end
end
