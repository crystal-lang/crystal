module Crystal::System::User
  def system_username
    raise NotImplementedError.new("Crystal::System::User#system_username")
  end

  def system_id
    raise NotImplementedError.new("Crystal::System::User#system_id")
  end

  def system_group_id
    raise NotImplementedError.new("Crystal::System::User#system_group_id")
  end

  def system_name
    raise NotImplementedError.new("Crystal::System::User#system_name")
  end

  def system_home_directory
    raise NotImplementedError.new("Crystal::System::User#system_home_directory")
  end

  def system_shell
    raise NotImplementedError.new("Crystal::System::User#system_shell")
  end

  def self.from_username?(username : String)
    raise NotImplementedError.new("Crystal::System::User.from_username?")
  end

  def self.from_id?(id : String)
    raise NotImplementedError.new("Crystal::System::User.from_id?")
  end
end
