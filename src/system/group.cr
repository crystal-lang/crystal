require "crystal/system/group"

class System::Group
  class NotFound < Exception
  end

  private getter sys_group : Crystal::System::Group

  private def initialize(@sys_group)
  end

  def self.from_name?(name)
    sys_group = Crystal::System::Group.from_name?(name)
    new(sys_group) if sys_group
  end

  def self.from_name(name)
    self.from_name?(name) || raise NotFound.new("no such group: #{name}")
  end

  def self.from_id?(id)
    sys_group = Crystal::System::Group.from_id?(id)
    new(sys_group) if sys_group
  end

  def self.from_id(id)
    self.from_id?(id) || raise NotFound.new("no such group: #{id}")
  end

  delegate name, password, id, members, to: @sys_group
end
