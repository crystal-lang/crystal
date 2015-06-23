class Object
  def save(io : IO)
    save(Marshaler.new(io))
  end

  def self.load(io : IO)
    load(Unmarshaler.new(io))
  end
end
