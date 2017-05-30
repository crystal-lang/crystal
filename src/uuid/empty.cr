struct UUID
  def self.empty
    #initialize UUID::Version::V4, StaticArray(UInt8, 16).new(0_u8)
    new StaticArray(UInt8, 16).new(0_u8)
  end
end
