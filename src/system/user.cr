require "crystal/system/user"

class System::User
  class NotFound < Exception
  end

  private getter sys_user : Crystal::System::User

  private def initialize(@sys_user)
  end

  def self.from_name?(name)
    sys_user = Crystal::System::User.from_name?(name)
    new(sys_user) if sys_user
  end

  def self.from_name(name)
    self.from_name?(name) || raise NotFound.new("no such user: #{name}")
  end

  def self.from_id?(id)
    sys_user = Crystal::System::User.from_id?(id)
    new(sys_user) if sys_user
  end

  def self.from_id(id)
    self.from_id?(id) || raise NotFound.new("no such user: #{id}")
  end

  delegate name, password, user_id, group_id, directory, shell, to: @sys_user
end
