struct Enum
  def save(output : Marshaler)
    output.write_int(value)
  end

  def self.load(input : Unmarshaler)
    self.new input.read_int.to_i
  end
end
