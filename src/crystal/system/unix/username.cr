require "c/pwd"

module Crystal::System
  def self.current_user_name
    if (pwd = getpwuid(LibC.getuid))
      String.new(pwd.pw_name)
    else
      raise RuntimeError.from_errno("Could not get current user name")
    end
  end
end
