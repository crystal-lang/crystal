require "./repl"

class Crystal::Repl::InstructionsCompiler < Crystal::Visitor
  alias Instruction = Int64

  def initialize(@program : Program)
    @instructions = [] of Instruction
  end

  def compile(node : ASTNode) : Array(Instruction)
    @instructions.clear
    node.accept self
    @instructions << OpCode::LEAVE.value
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
end
