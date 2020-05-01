module Crystal
  class ImplicitBlockArgumentDetector < Visitor
    def self.has_implicit_block_arguments?(block : Block)
      detector = new
      block.body.accept(detector)
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

    def visit(node : Block)
      false
    end

    def visit(node : ASTNode)
      !@has_implicit_block_arguments
    end
  end

  class ImplicitBlockArgumentTransformer < Transformer
    def self.transform(program : Program, block : Block)
      transformer = new(program, block)
      block.body = block.body.transform(transformer)
    end

    @initial_block_args_size : Int32

    def initialize(@program : Program, @block : Block)
      @initial_block_args_size = @block.args.try(&.size) || 0
    end

    def transform(node : ExpandableNode | Call)
      expanded = node.expanded
      if expanded
        node.expanded = expanded.transform(self)
        node
      else
        super
      end
    end

    def transform(node : Block)
      # Don't go inside nested blocks
      node
    end

    def transform(node : ImplicitBlockArgument)
      number = node.number

      if @initial_block_args_size >= number
        node.raise "an explicit block argument at position #{number} already exists"
      end

      args = @block.args ||= [] of Var

      (number - args.size).times do |i|
        args << @program.new_temp_var
      end

      args[number - 1].clone.at(node)
    end
  end
end
