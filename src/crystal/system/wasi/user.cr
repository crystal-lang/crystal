module Crystal::System::User
  private def from_username?(username : String)
    raise NotImplementedError.new("Crystal::System::User#from_username?")
  end

  private def from_id?(id : String)
    raise NotImplementedError.new("Crystal::System::User#from_id?")
  end

  private def find_curent_user_name
    raise NotImplementedError.new("Crystal::System::User#find_current_user_name")
  end
end
