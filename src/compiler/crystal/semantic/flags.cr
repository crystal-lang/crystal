class Crystal::Program
  def flags
    @flags ||= parse_flags(target_machine.triple.split('-'))
  end

  def flags=(flags)
    @flags = parse_flags(flags.split)
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
    set = flags_name.map(&.downcase).to_set
    set.add "darwin" if set.any?(&.starts_with?("macosx"))
    set.add "freebsd" if set.any?(&.starts_with?("freebsd"))
    set.add "i686" if set.any? { |flag| %w(i586 i486 i386).includes?(flag) }
    set
  end

  class FlagsEvaluator < Visitor
    getter value : Bool
    @program : Program

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
