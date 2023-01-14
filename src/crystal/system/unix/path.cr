require "./user"

module Crystal::System::Path
  def self.home : String
    if home_path = ENV["HOME"]?.presence
      home_path
    else
      pwd = System.getpwuid(LibC.getuid)
      raise RuntimeError.new("Could not determine current user's home directory") unless pwd
      String.new(pwd.pw_dir)
    end
  end
end
