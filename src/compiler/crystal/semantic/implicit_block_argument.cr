module Crystal
  class ImplicitBlockArgumentDetector < Visitor
    def self.has_implicit_block_arguments?(node : ASTNode)
      detector = new
      node.accept(detector)
      detector.has_implicit_block_arguments?
    end

    getter? has_implicit_block_arguments = false

    def visit(node : ImplicitBlockArgument)
      @has_implicit_block_arguments = true
    end

    def visit(node : ExpandableNode | Call)
      if expanded = node.expanded
        expanded.accept(self)
        false
      else
        true
      end
    end

    def visit(node : ASTNode)
      !@has_implicit_block_arguments
    end
  end

  class ImplicitBlockArgumentExpander < Transformer
    def self.expand(program : Program, node : ASTNode)
      transformer = new(program)
      node.transform(transformer)
      block = transformer.block
      block.body = node
      block.at(node)
      block
    end

    getter block : Block

    def initialize(@program : Program)
      @block = Block.new
    end

    def transform(node : ExpandableNode | Call)
      expanded = node.expanded
      if expanded
        node.expanded = expanded.transform(self)
        node
      else
        # TODO: don't go inside Call block_arg
        super
      end
    end

    def transform(node : Block)
      # Don't go inside nested blocks
      node
    end

    def transform(node : ImplicitBlockArgument)
      number = node.number

      args = @block.args ||= [] of Var

      (number - args.size).times do |i|
        args << @program.new_temp_var
      end

      args[number - 1].clone.at(node)
    end
  end
end
