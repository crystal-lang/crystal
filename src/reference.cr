class Reference
  def ==(other : self)
    same?(other)
  end

  def ==(other)
    false
  end

  def same?(other : Reference)
    object_id == other.object_id
  end

  def same?(other : Nil)
    false
  end

  def nil?
    false
  end

  def !
    false
  end

  def hash
    object_id
  end

  def clone
    self
  end

  def inspect : String
    hex_object_id = object_id.to_s(16)
    exec_recursive(:inspect, "#<{{@name.id}}:0x#{hex_object_id} ...>") do
      String.build do |str|
        str << "#<"
        str << {{@name}}
        str << ":0x"
        str << hex_object_id
        {% for ivar, i in @instance_vars %}
          {% if i > 0 %}
            str << ","
          {% end %}
          str << " {{ivar.id}}="
          str << {{ivar.id}}.inspect
        {% end %}
        str << ">"
      end
    end
  end

  def to_s : String
    hex_object_id = object_id.to_s(16)
    "#<{{@name.id}}:0x#{hex_object_id}>"
  end

  def exec_recursive(method, default_value)
    # hash = (@:ThreadLocal $_exec_recursive ||= {} of Tuple(UInt64, Symbol) => Bool)
    hash = ($_exec_recursive ||= {} of Tuple(UInt64, Symbol) => Bool)
    key = {object_id, method}
    if hash[key]?
      default_value
    else
      hash[key] = true
      value = yield
      hash.delete(key)
      value
    end
  end
end
