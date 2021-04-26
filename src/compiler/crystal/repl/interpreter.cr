require "./repl"

class Crystal::Repl::Interpreter < Crystal::Visitor
  getter last : Value
  getter vars : Hash(String, Value)

  def initialize(@program : Program)
    @last = Value.new(nil, @program.nil_type)
    @vars = {} of String => Value
  end

  def interpret(node)
    node.accept self
    @last
  end

  def visit(node : NilLiteral)
    @last = Value.new(nil, @program.nil_type)
    false
  end

  def visit(node : BoolLiteral)
    @last = Value.new(node.value, @program.bool)
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i32
      @last = Value.new(node.value.to_i, @program.int32)
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
    false
  end

  def visit(node : Assign)
    visit(node, node.target, node.value)
    false
  end

  def visit(node : Var)
    @last = @vars[node.name]
    false
  end

  private def visit(node : Assign, target : Var, value : ASTNode)
    value.accept self
    @vars[target.name] = @last
  end

  private def visit(node : Assign, target : ASTNode, value : ASTNode)
    node.raise "BUG: missing interpret for #{node.class} with target #{node.target.class}"
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end
end
