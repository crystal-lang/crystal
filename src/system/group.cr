require "crystal/system/group"

class System::Group
  # Raised on group lookup failure.
  class NotFound < Exception
  end

  private def initialize(@sys_group : Crystal::System::Group)
  end

  # Returns the group associated with the given name, if it exists.
  #
  # Raises `Errno` if a system error occurs.
  def self.from_name?(name)
    sys_group = Crystal::System::Group.from_name?(name)
    new(sys_group) if sys_group
  end

  # Returns the group associated with the given name.
  #
  # Raises `NotFound` if no such group exists.
  # See `from_name?`.
  def self.from_name(name)
    from_name?(name) || raise NotFound.new("No such group: #{name}")
  end

  # Returns the group associated with the given ID, if it exists.
  #
  # Raises `Errno` if a system error occurs.
  def self.from_id?(id)
    sys_group = Crystal::System::Group.from_id?(id)
    new(sys_group) if sys_group
  end

  # Returns the group associated with the given ID.
  #
  # Raises `NotFound` if no such group exists.
  # See `from_id?`.
  def self.from_id(id)
    from_id?(id) || raise NotFound.new("No such group: #{id}")
  end

  # Returns the group's name.
  delegate name, to: @sys_group

  # Returns the group's password.
  delegate password, to: @sys_group

  # Returns the group's ID.
  delegate id, to: @sys_group

  # Returns an array of the group's members.
  delegate members, to: @sys_group
end
