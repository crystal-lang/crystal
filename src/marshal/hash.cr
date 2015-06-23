class Hash(K, V)
  protected def internal_save(output : Marshaler)
    size.save(output)
    each do |k, v|
      ValueMarshaler(K).save(k, output)
      ValueMarshaler(V).save(v, output)
    end
  end

  protected def self.internal_load(input : Unmarshaler)
    size = Int32.load(input)
    value = self.new
    yield value
    size.times do
      k = ValueMarshaler(K).load(input)
      v = ValueMarshaler(V).load(input)
      value[k] = v
    end
    value
  end
end
