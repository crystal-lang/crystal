class Array(T)
  protected def internal_save(output : Marshaler)
    size.save(output)
    each do |item|
      ValueMarshaler(T).save(item, output)
    end
  end

  protected def self.internal_load(input : Unmarshaler)
    length = Int32.load(input)
    arr = Array(T).new(length)
    yield arr
    length.times do
      arr << ValueMarshaler(T).load(input)
    end
    arr
  end
end
