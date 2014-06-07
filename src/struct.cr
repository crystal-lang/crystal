struct Struct
  def hash : Int32
    hash = 0
    {% for ivar in @instance_vars %}
      hash = 31 * hash + {{ivar}}.hash
    {% end %}
    hash
  end

  def to_s : String
    String.build do |str|
      str << {{@name.stringify}}
      str << "("
      {% for ivar, i in @instance_vars %}
        {% if i > 0 %}
          str << ", "
        {% end %}
        str << "{{ivar}}="
        str << {{ivar}}.inspect
      {% end %}
      str << ")"
    end
  end
end
