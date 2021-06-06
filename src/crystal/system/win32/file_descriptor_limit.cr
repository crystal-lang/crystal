module Crystal::System
  def self.file_descriptor_limit : Tuple(Int32, Int32)
    raise NotImplementedError.new
  end

  def self.file_descriptor_limit=(limit : Int) : Nil
    raise NotImplementedError.new
  end
end
