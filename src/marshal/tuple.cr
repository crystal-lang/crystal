struct Tuple
  def save(output : Marshaler)
    {% for i in 0 ... @length %}
      ValueMarshaler(typeof(self[{{i}}])).save(self[{{i}}], output)
    {% end %}
  end

  macro def self.load(input : Unmarshaler) : self
      Tuple.new(
        {% for i in 0 ... @length %}
          ValueMarshaler({{@type.type_params[i]}}).load(input),
        {% end %}
      )
  end
end
