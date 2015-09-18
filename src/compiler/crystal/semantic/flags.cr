class Crystal::Program
  def flags
    unless @flags
      # Try to reconstruct the expected best "uname" info from the triple.
      # Running real "uname" is not always a good idea because it may be,
      # for example, a 32-bit x86 system running with a 64-bit linux kernel.
      case LLVM.default_target_triple
      when /^x86_64\-.*\-linux\-gnu/
        @flags = parse_flags("Linux x86_64")
      when /^i(\d)86.*\-linux\-gnu/
        if $1.to_i > 3
          @flags = parse_flags("Linux i686")
        else
          @flags = parse_flags("Linux i386")
        end
      when /^armv7.*\-linux/
        @flags = parse_flags("Linux armv7l")
      when /^arm.*\-linux/
        @flags = parse_flags("Linux armv6l")
      end
    end
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
