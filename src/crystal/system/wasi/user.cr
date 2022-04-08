module Crystal::System::User
  private def from_username?(username : String)
    raise NotImplementedError.new("Crystal::System::User#from_username?")
  end

  private def from_id?(id : String)
    raise NotImplementedError.new("Crystal::System::User#from_id?")
  end
end
