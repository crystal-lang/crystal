module Crystal::System
  def self.hostname
    raise NotImplementedError.new("Crystal::System.hostname")
  end
end
