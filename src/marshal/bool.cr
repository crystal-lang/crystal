struct Bool
  def save(output : Marshaler)
    (self ? 1_u8 : 0_u8).save(output)
  end

  def self.load(input : Unmarshaler)
    UInt8.load(input) == 1_u8
  end
end
