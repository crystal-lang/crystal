require "c/unistd"

module Crystal::System
  def self.login
    String.new(LibC.getlogin)
  end
end
