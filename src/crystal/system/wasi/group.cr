module Crystal::System::Group
  private def from_name?(groupname : String)
    raise NotImplementedError.new("Crystal::System::Group#from_name?")
  end

  private def from_id?(groupid : String)
    raise NotImplementedError.new("Crystal::System::Group#from_id?")
  end
end
