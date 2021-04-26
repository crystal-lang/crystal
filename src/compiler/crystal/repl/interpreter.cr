require "./repl"

class Crystal::Repl::Interpreter < Crystal::Visitor
  getter last

  def initialize
    @program = Program.new
    @last = Value.new(nil, @program.nil_type)
  end

  def interpret(node)
    node.accept self
    @last
  end

  def visit(node : NumberLiteral)
    case node.kind
    when :i32
      @last = Value.new(node.value.to_i, @program.int32)
    else
      node.raise "BUG: missing interpret for NumberLiteral with kind #{node.kind}"
    end
  end

  def visit(node : ASTNode)
    node.raise "BUG: missing interpret for #{node.class}"
  end
end
