require "c/unistd"

module Crystal::System
  def self.login
    if login = LibC.getlogin
      String.new(login)
    else
      Nil
    end
  end
end
