require "./repl"

module Crystal::Repl::Disassembler
  def self.disassemble(compiled_def : CompiledDef) : String
    disassemble(compiled_def.instructions, compiled_def.local_vars)
  end

  def self.disassemble(instructions : Array(Instruction), local_vars : LocalVars) : String
    String.build do |io|
      ip = 0
      while ip < instructions.size
        ip = disassemble_one(instructions, ip, local_vars, io)
      end
    end
  end

  def self.disassemble_one(instructions : Array(Instruction), ip : Int32, local_vars : LocalVars, io : IO) : Int32
    io.print ip.to_s.rjust(4, '0')
    io.print ' '
    op_code, ip = next_instruction instructions, ip, OpCode

    {% begin %}
      case op_code
        {% for name, instruction in Crystal::Repl::Instructions %}
          in .{{name.id}}?
            io.print "{{name}}"
            {% for operand in instruction[:operands] %}
              {{operand.var}}, ip = next_instruction instructions, ip, {{operand.type}}
            {% end %}

            {% if instruction[:disassemble] %}
              {% for name, disassemble in instruction[:disassemble] %}
                {{name.id}} = {{disassemble}}
              {% end %}
            {% end %}

            {% for operand in instruction[:operands] %}
              io.print " "
              io.print {{operand.var}}
            {% end %}
            io.puts
        {% end %}
      end
    {% end %}

    ip
  end

  private def self.next_instruction(instructions, ip, t : T.class) forall T
    {
      (instructions.to_unsafe + ip).as(T*).value,
      ip + sizeof(T),
    }
  end
end
