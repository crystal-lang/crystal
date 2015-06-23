class Reference
  include InstanceVariableMarshaler

  protected macro def save(output : Marshaler) : Nil
    return if output.put_reference(self)
    internal_save(output)
    nil
  end

  protected macro def internal_save(output : Marshaler) : Nil
    {% for ivar in @type.instance_vars %}\
      ValueMarshaler(typeof(@{{ivar.id}})).save(@{{ivar.id}}, output)
    {% end %}
    nil
  end

  def self.load(input : Unmarshaler) : self
    if ref = input.get_reference
      ref as self
    else
      internal_load(input) do |ref|
        input.save_reference(ref)
      end
    end
  end

  protected def self.internal_load(input : Unmarshaler)
    obj = self.allocate
    yield obj
    obj.unmarshal_instance_variables(input)
    obj
  end
end
