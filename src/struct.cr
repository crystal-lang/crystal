struct Struct
  def ==(other : self) : Bool
    {% for ivar in @instance_vars %}
      return false unless @{{ivar.id}} == other.@{{ivar.id}}
    {% end %}
    true
  end

  def hash : Int32
    hash = 0
    {% for ivar in @instance_vars %}
      hash = 31 * hash + @{{ivar.id}}.hash
    {% end %}
    hash
  end

  def to_s(io : IO) : Nil
    io << "{{@class_name.id}}("
    {% for ivar, i in @instance_vars %}
      {% if i > 0 %}
        io << ", "
      {% end %}
      io << "@{{ivar.id}}="
      @{{ivar.id}}.inspect(io)
    {% end %}
    io << ")"
    nil
  end
end
