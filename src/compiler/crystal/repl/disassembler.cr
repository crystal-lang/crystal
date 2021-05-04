require "./repl"

module Crystal::Repl::Disassembler
  def self.disassemble(instructions : Array(Instruction), local_vars : LocalVars) : String
    String.build do |io|
      ip = 0
      while ip < instructions.size
        io.print ip.to_s.rjust(4, '0')
        io.print ' '
        op_code, ip = next_instruction instructions, ip, OpCode

        case op_code
        in .put_nil?
          io.puts "put_nil"
        in .put_false?
          io.puts "put_false"
        in .put_true?
          io.puts "put_true"
        in .put_object?
          io.print "put_object "
          value, ip = next_instruction instructions, ip, Pointer(Void)
          type, ip = next_instruction instructions, ip, Type
          repl_value = Value.new(value, type)
          io.print repl_value.value.inspect
          io.print " ("
          io.print repl_value.type
          io.puts ")"
        in .set_local?
          io.print "set_local "
          index, ip = next_instruction instructions, ip, Int32
          name = local_vars.index_to_name(index)
          io.print name
          io.print '@'
          io.puts index
        in .get_local?
          io.print "get_local "
          index, ip = next_instruction instructions, ip, Int32
          name = local_vars.index_to_name(index)
          io.print name
          io.print '@'
          io.puts index
        in .binary_plus?
          io.puts "binary_plus"
        in .binary_minus?
          io.puts "binary_minus"
        in .binary_mult?
          io.puts "binary_mult"
        in .binary_lt?
          io.puts "binary_lt"
        in .binary_le?
          io.puts "binary_le"
        in .binary_gt?
          io.puts "binary_gt"
        in .binary_ge?
          io.puts "binary_ge"
        in .binary_eq?
          io.puts "binary_eq"
        in .binary_neq?
          io.puts "binary_neq"
        in .branch_if?
          index, ip = next_instruction instructions, ip, Int32
          io.print "branch_if "
          io.puts index
        in .branch_unless?
          index, ip = next_instruction instructions, ip, Int32
          io.print "branch_unless "
          io.puts index
        in .jump?
          index, ip = next_instruction instructions, ip, Int32
          io.print "jump "
          io.puts index
        in .pop?
          io.puts "pop"
        in .pointer_malloc?
          io.puts "pointer_malloc"
        in .pointer_set?
          io.puts "pointer_set"
        in .pointer_get?
          io.puts "pointer_get"
        in .leave?
          io.puts "leave"
        end
      end
    end
  end

  private def self.next_instruction(instructions, ip, t : T.class) forall T
    value = instructions[ip].unsafe_as(T)
    ip += 1
    {value, ip}
  end
end
