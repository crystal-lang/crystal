class String
  protected def internal_save(output : Marshaler)
    output.write_string(self)
  end

  protected def self.internal_load(input : Unmarshaler)
    str = input.read_string
    yield str
    str
  end
end
