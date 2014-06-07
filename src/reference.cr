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
    String.build do |str|
      str << "#<"
      str << {{@name.stringify}}
      str << ":0x"
      str << object_id.to_s(16)
      {% for ivar, i in @instance_vars %}
        {% if i > 0 %}
          str << ","
        {% end %}
        str << " {{ivar}}="
        str << {{ivar}}.inspect
      {% end %}
      str << ">"
    end
  end

  def to_s
    String.new(to_cstr)
  end
end
