module Crystal::System::Group
  def system_name
    raise NotImplementedError.new("Crystal::System::Group#system_name")
  end

  def system_id
    raise NotImplementedError.new("Crystal::System::Group#system_id")
  end

  def self.from_name?(groupname : String)
    raise NotImplementedError.new("Crystal::System::Group.from_name?")
  end

  def self.from_id?(groupid : String)
    raise NotImplementedError.new("Crystal::System::Group.from_id?")
  end
end
