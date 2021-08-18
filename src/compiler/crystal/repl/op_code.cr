require "./repl"
require "./instructions"

{% begin %}
  enum Crystal::Repl::OpCode : UInt8
    {% for name, instruction, i in Crystal::Repl::Instructions %}
      {{ name.id.upcase }} = {{ i }}
    {% end %}
  end
{% end %}
