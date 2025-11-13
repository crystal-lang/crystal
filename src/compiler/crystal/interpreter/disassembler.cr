require "./repl"

# Allows showing bytecode in a human-readable way.
# TODO: right now local variables are not very nicely.
module Crystal::Repl::Disassembler
  def self.disassemble(context : Context, compiled_def : CompiledDef) : String
    disassemble(context, compiled_def.instructions, compiled_def.local_vars)
  end

  def self.disassemble(context : Context, compiled_block : CompiledBlock) : String
    disassemble(context, compiled_block.instructions, compiled_block.local_vars)
  end

  def self.disassemble(context : Context, instructions : CompiledInstructions, local_vars : LocalVars) : String
    String.build do |io|
      exception_handlers = instructions.exception_handlers
      if exception_handlers
        io.puts "Catch table"
        io.puts "==========="
        exception_handlers.each do |handler|
          io << "st: " << handler.start_index << ", "
          io << "ed: " << handler.end_index << ", "
          if exception_types = handler.exception_types
            io << "ex: "
            exception_types.join(io, ", ")
            io << ", "
          end
          io << "cont: " << handler.jump_index
          io.puts
        end
      end

      ip = 0
      while ip < instructions.instructions.size
        ip = disassemble_one(context, instructions, ip, local_vars, io)
      end
    end
  end

  def self.disassemble_one(context : Context, instructions : CompiledInstructions, ip : Int32, local_vars : LocalVars, io : IO) : Int32
    io.print ip.to_s.rjust(4, '0')
    io.print ' '

    node = instructions.nodes[ip]?
    op_code, ip = next_instruction instructions, ip, OpCode

    {% begin %}
      case op_code
        {% for name, instruction in Crystal::Repl::Instructions %}
          in .{{name.id}}?
            io.print "{{name}}"
            {% for operand in instruction[:operands] || [] of Nil %}
              {{operand.var}}, ip = next_instruction instructions, ip, {{operand.type}}
            {% end %}

            {% if instruction[:disassemble] %}
              {% for name, disassemble in instruction[:disassemble] %}
                {{name.id}} = {{disassemble}}
              {% end %}
            {% end %}

            {% for operand in instruction[:operands] || [] of Nil %}
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
      (instructions.instructions.to_unsafe + ip).as(T*).value,
      ip + sizeof(T),
    }
  end
end
