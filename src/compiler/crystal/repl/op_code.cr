require "./repl"
require "./instructions"

{% begin %}
  enum Crystal::Repl::OpCode : UInt8
    {% for name, instruction in Crystal::Repl::Instructions %}
      {{ name.id.upcase }}
    {% end %}
  end
{% end %}
