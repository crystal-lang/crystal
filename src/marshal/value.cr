struct Value
  macro def save(output : Marshaler) : Nil
    {% for ivar in @type.instance_vars %}
      ValueMarshaler(typeof(@{{ivar.id}})).save(@{{ivar.id}}, output)
    {% end %}
    nil
  end

  def self.load(input : Unmarshaler) : self
    obj = self.allocate
    obj.marshal_from(input)
    obj
  end

  protected macro def marshal_from(input) : Nil
    {% for ivar in @type.instance_vars %}
      @{{ivar.id}} = ValueMarshaler(typeof(@{{ivar.id}})).load(input)
    {% end %}
    nil
  end
end
