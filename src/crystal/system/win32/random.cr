module Crystal::System::Random
  def self.random_bytes(buf : Bytes) : Nil
    raise NotImplementedError.new("Crystal::System::Random.random_bytes")
  end

  def self.next_u : UInt8
    raise NotImplementedError.new("Crystal::System::Random.next_u")
  end
end
