struct Float
  def save(output : Marshaler)
    output.write_float(self)
  end

  def self.load(input : Unmarshaler)
    input.read_float
  end
end
