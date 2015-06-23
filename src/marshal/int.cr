struct Int
  def save(output : Marshaler)
    output.write_int(self)
  end

  def self.load(input : Unmarshaler)
    self.cast(input.read_int)
  end
end
