module Crystal::System
  def self.file_descriptor_limit
    raise NotImplementedError.new
  end

  def self.file_descriptor_limit=(limit : UInt32) : Nil
    raise NotImplementedError.new
  end
end
