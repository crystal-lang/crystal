module Crystal
  class Playground::AgentInstrumentorTransformer < Transformer
    class FirstBlockVisitor < Visitor
      def initialize(@instrumentor)
      end

      def visit(node : Call)
        if node_block = node.block
          @instrumentor.ignoring_line_of_node node do
            node.block = node_block.transform(@instrumentor)
          end
        end
        false
      end

      def visit(node)
        true
      end
    end

    class TypeBodyTransformer < Transformer
      def initialize(@instrumentor)
      end

      def transform(node : Def)
        @instrumentor.transform(node)
      end
    end

    property ignore_line
    @nested_block_visitor : FirstBlockVisitor?
    @type_body_transformer : TypeBodyTransformer?

    def initialize
      @ignore_line = nil
      @nested_block_visitor = FirstBlockVisitor.new(self)
      @type_body_transformer = TypeBodyTransformer.new(self)
    end

    private def instrument(node)
      if (location = node.location) && location.line_number != ignore_line
        @nested_block_visitor.not_nil!.accept(node)
        args = [node as ASTNode, NumberLiteral.new(location.line_number)] of ASTNode
        if node.is_a?(TupleLiteral)
          args << ArrayLiteral.new(node.elements.map { |e| StringLiteral.new(e.to_s) as ASTNode })
        end
        Call.new(Global.new("$p"), "i", args)
      else
        node
      end
    end

    def transform(node : Assign)
      # constants are Path, avoid instrumenting those assignments
      unless node.target.is_a?(Path)
        node.value = instrument(node.value)
      end
      node
    end

    def transform(node : MultiAssign)
      node.values = if node.values.size == 1
                      [instrument(node.values[0])]
                    else
                      rhs = TupleLiteral.new(node.values)
                      rhs.location = node.location
                      [instrument(rhs)]
                    end
      node
    end

    def transform(node : NilLiteral | NumberLiteral | StringLiteral | BoolLiteral | CharLiteral | SymbolLiteral | TupleLiteral | ArrayLiteral | StringInterpolation | RegexLiteral | Var | InstanceVar | ClassVar | Global | TypeOf)
      instrument(node)
    end

    def transform(node : Call)
      case {node.obj, node.name, node.args.size}
      when {nil, "raise", 1}
        instrument_arg node
      when {nil, "puts", 1}
        instrument_arg node
      when {nil, "puts", _}
        instrument_args_and_splat node
      when {nil, "print", 1}
        instrument_arg node
      when {nil, "print", _}
        instrument_args_and_splat node
      when {nil, "record", _}
        node
      else
        instrument(node)
      end
    end

    private def instrument_arg(node : Call)
      node.args[0] = instrument(node.args[0])
      node
    end

    private def instrument_args_and_splat(node : Call)
      args = TupleLiteral.new(node.args)
      args.location = node.location
      node.args = [Splat.new(instrument(args))] of ASTNode
      node
    end

    def transform(node : Yield)
      node.exps[0] = instrument(node.exps[0]) if node.exps.size == 1
      node
    end

    def transform(node : If | Unless)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform(node : Case)
      node.whens.each do |w|
        w.body = w.body.transform(self)
      end
      if e = node.else
        node.else = e.transform(self)
      end
      node
    end

    def transform(node : While)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : Return)
      if exp = node.exp
        node.exp = instrument(exp)
      end
      node
    end

    def transform(node : Def)
      ignoring_line_of_node node do
        node.body = node.body.transform(self)
        node
      end
    end

    def transform(node : ClassDef | ModuleDef)
      node.body = @type_body_transformer.not_nil!.transform(node.body)
      node
    end

    def transform(node : Expressions)
      node.expressions = node.expressions.map(&.transform(self) as ASTNode).to_a
      node
    end

    def transform(node : Block)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : ExceptionHandler)
      node.body = node.body.transform(self)
      node.rescues = transform_many(node.rescues)
      if node_else = node.else
        node.else = node_else.transform(self)
      end
      if node_ensure = node.ensure
        node.ensure = node_ensure.transform(self)
      end
      node
    end

    def transform(node : Rescue)
      node.body = node.body.transform(self)
      node
    end

    def transform(node)
      node
    end

    def ignoring_line_of_node(node)
      old_ignore_line = @ignore_line
      @ignore_line = node.location.try(&.line_number)
      res = yield
      @ignore_line = old_ignore_line
      res
    end
  end
end
