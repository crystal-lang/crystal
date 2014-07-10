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

  def inspect(io : IO) : Nil
    io << "#<{{@class_name.id}}:0x"
    object_id.to_s(16, io)

    executed = exec_recursive(:inspect) do
      {% for ivar, i in @instance_vars %}
        {% if i > 0 %}
          io << ","
        {% end %}
        io << " @{{ivar.id}}="
        @{{ivar.id}}.inspect io
      {% end %}
    end
    unless executed
      io << " ..."
    end
    io << ">"
    nil
  end

  def to_s(io : IO) : Nil
    io << "#<{{@class_name.id}}:0x"
    object_id.to_s(16, io)
    io << ">"
    nil
  end

  def exec_recursive(method)
    # hash = (@:ThreadLocal $_exec_recursive ||= {} of Tuple(UInt64, Symbol) => Bool)
    hash = ($_exec_recursive ||= {} of Tuple(UInt64, Symbol) => Bool)
    key = {object_id, method}
    if hash[key]?
      false
    else
      hash[key] = true
      value = yield
      hash.delete(key)
      true
    end
  end
end
