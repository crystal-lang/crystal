struct UUID
  def self.empty
    self.new Version::V4, StaticArray(UInt8, 16).new(0_u8)
  end
end
