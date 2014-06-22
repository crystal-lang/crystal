struct Struct
  def ==(other : self) : Bool
    {% for ivar in @instance_vars %}
      return false unless {{ivar.id}} == other.{{ivar.id}}
    {% end %}
    true
  end

  def hash : Int32
    hash = 0
    {% for ivar in @instance_vars %}
      hash = 31 * hash + {{ivar.id}}.hash
    {% end %}
    hash
  end

  def to_s : String
    String.build do |str|
      str << {{@name}}
      str << "("
      {% for ivar, i in @instance_vars %}
        {% if i > 0 %}
          str << ", "
        {% end %}
        str << "{{ivar.id}}="
        str << {{ivar.id}}.inspect
      {% end %}
      str << ")"
    end
  end
end
