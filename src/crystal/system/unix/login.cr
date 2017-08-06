require "c/unistd"

module Crystal::System
  def self.login
    if LibC.getlogin
      String.new(LibC.getlogin)
    else
      Nil
    end
  end
end
