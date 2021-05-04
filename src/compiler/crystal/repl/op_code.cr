require "./repl"
require "./instructions"

{% begin %}
  enum Crystal::Repl::OpCode : Int64
    {% for name, instruction in Crystal::Repl::Instructions %}
      {{ name.id.upcase }}
    {% end %}
  end
{% end %}
