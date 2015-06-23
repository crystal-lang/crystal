struct Char
  def save(output : Marshaler)
    ord.save(output)
  end

  def self.load(input : Unmarshaler)
    Int32.load(input).chr
  end
end
