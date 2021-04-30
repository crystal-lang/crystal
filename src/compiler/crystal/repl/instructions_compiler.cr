require "./repl"

class Crystal::Repl::InstructionsCompiler < Crystal::Visitor
  alias Instruction = Int64

  def initialize(@program : Program, @local_vars : LocalVars)
    @instructions = [] of Instruction
    @wants_value = true
  end

  def compile(node : ASTNode) : Array(Instruction)
    @instructions.clear
    @wants_value = true

    node.accept self

    leave

    # puts disassemble(@instructions)

    @instructions
  end

  def visit(node : Nop)
    put_nil
    false
  end

  def visit(node : NilLiteral)
    put_nil
    false
  end

  def visit(node : BoolLiteral)
    node.value ? put_true : put_false
    false
  end

  def visit(node : CharLiteral)
    put_object node.value.ord, node.type
    false
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i8
      put_object node.value.to_i8, node.type
    when :u8
      put_object node.value.to_u8, node.type
    when :i16
      put_object node.value.to_i16, node.type
    when :u16
      put_object node.value.to_u16, node.type
    when :i32
      put_object node.value.to_i32, node.type
    when :u32
      put_object node.value.to_u32, node.type
    when :i64
      put_object node.value.to_i64, node.type
    when :u64
      put_object node.value.to_u64, node.type
    when :f32
      put_object node.value.to_f32, node.type
    when :f64
      put_object node.value.to_f64, node.type
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : StringLiteral)
    put_object node.value.object_id, node.type
    false
  end

  def visit(node : Expressions)
    old_wants_value = @wants_value
    node.expressions.each_with_index do |expression, i|
      @wants_value = old_wants_value && i == node.expressions.size - 1
      expression.accept self
    end
    @wants_value = old_wants_value
    false
  end

  def visit(node : Assign)
    target = node.target
    case target
    when Var
      node.value.accept self
      dup! if @wants_value
      index = @local_vars.name_to_index(target.name)
      set_local index
    else
      node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
    end
    false
  end

  def visit(node : Var)
    index = @local_vars.name_to_index(node.name)
    get_local index
    false
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing instruction compiler for #{node.class}"
  end

  private def put_nil : Nil
    @instructions << OpCode::PUT_NIL.value
  end

  private def put_false : Nil
    @instructions << OpCode::PUT_FALSE.value
  end

  private def put_true : Nil
    @instructions << OpCode::PUT_TRUE.value
  end

  private def put_object(value, type) : Nil
    @instructions << OpCode::PUT_OBJECT.value
    @instructions << value.unsafe_as(Int64)
    @instructions << type.object_id.unsafe_as(Int64)
  end

  private def set_local(index : Int32) : Nil
    @instructions << OpCode::SET_LOCAL.value
    @instructions << index.unsafe_as(Int64)
  end

  private def get_local(index : Int32) : Nil
    @instructions << OpCode::GET_LOCAL.value
    @instructions << index.unsafe_as(Int64)
  end

  private def dup!
    @instructions << OpCode::DUP.value
  end

  private def leave
    @instructions << OpCode::LEAVE.value
  end

  private def disassemble(instructions : Array(Instruction)) : String
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
          name = @local_vars.index_to_name(index)
          io.print name
          io.print '@'
          io.puts index
        in .get_local?
          io.print "get_local "
          index, ip = next_instruction instructions, ip, Int32
          name = @local_vars.index_to_name(index)
          io.print name
          io.print '@'
          io.puts index
        in .dup?
          io.puts "dup"
        in .leave?
          io.puts "leave"
        end
      end
    end
  end

  private def next_instruction(instructions, ip, t : T.class) forall T
    value = instructions[ip].unsafe_as(T)
    ip += 1
    {value, ip}
  end
end
