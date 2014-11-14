class Crystal::Program
  def flags
    @flags ||= parse_flags(`uname -m -s`)
  end

  def flags=(flags)
    @flags = parse_flags(flags)
  end

  def has_flag?(name)
    flags.includes?(name)
  end

  def eval_flags(node)
    evaluator = FlagsEvaluator.new(self)
    node.accept evaluator
    evaluator.value
  end

  private def parse_flags(flags_name)
    flags_name.split.map(&.downcase).to_set
  end

  class FlagsEvaluator < Visitor
    getter value

    def initialize(@program)
      @value = false
    end

    def visit(node : Var)
      @value = @program.has_flag?(node.name)
    end

    def visit(node : Not)
      node.exp.accept self
      @value = !@value
      false
    end

    def visit(node : And)
      node.left.accept self
      left_value = @value
      node.right.accept self
      @value = left_value && @value
      false
    end

    def visit(node : Or)
      node.left.accept self
      left_value = @value
      node.right.accept self
      @value = left_value || @value
      false
    end

    def visit(node : ASTNode)
      raise "Bug: shouldn't visit #{node} in FlagsEvaluator"
    end
  end
end
