module Crystal::System::Path
  def self.home : String
    ENV["HOME"]
  end
end
