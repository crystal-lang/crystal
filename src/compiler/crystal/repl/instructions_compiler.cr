require "./repl"

class Crystal::Repl::InstructionsCompiler < Crystal::Visitor
  alias Instruction = Int64

  def initialize(@program : Program, @local_vars : LocalVars)
    @instructions = [] of Instruction
    @last = true
  end

  def compile(node : ASTNode) : Array(Instruction)
    @instructions.clear
    @last = true

    node.accept self

    leave

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
    node.expressions.each_with_index do |expression, i|
      @last = i == node.expressions.size - 1
      expression.accept self
    end
    false
  end

  def visit(node : Assign)
    target = node.target
    case target
    when Var
      node.value.accept self
      dup! if @last
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
end
