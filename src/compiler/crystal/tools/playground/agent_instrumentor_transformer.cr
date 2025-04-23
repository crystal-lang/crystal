module Crystal
  class Playground::AgentInstrumentorTransformer < Transformer
    class MacroDefNameCollector < Visitor
      getter names

      def initialize
        @names = Set(String).new
      end

      def visit(node : Macro)
        @names << node.name
        false
      end

      def visit(node)
        true
      end
    end

    class FirstBlockVisitor < Visitor
      def initialize(@instrumentor : AgentInstrumentorTransformer)
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
      def initialize(@instrumentor : AgentInstrumentorTransformer)
      end

      def transform(node : Def)
        @instrumentor.transform(node)
      end
    end

    property ignore_line : Int32?

    def initialize(@macro_names : Set(String))
      @macro_names << "record"

      @ignore_line = nil
      @nested_block_visitor = FirstBlockVisitor.new(self)
      @type_body_transformer = TypeBodyTransformer.new(self)
    end

    def self.transform(ast)
      # collect names of declared macros in ast
      # so the instrumentor can ignore call's of methods with this name
      # this will avoid instrumenting calls to methods with the same name than
      # declared macros in the playground source. For a more accurate solution
      # a compilation should be done to distinguish whether each call refers to a macro or
      # a method. Between the macro names collection and only instrumenting def's inside
      # modules/classes the generated instrumentation is pretty good enough. See #2355
      collector = MacroDefNameCollector.new
      ast.accept collector

      ast.transform self.new(collector.names)
    end

    private def instrument(node, add_as_typeof = false)
      if (location = node.location) && location.line_number != ignore_line
        splat = node.is_a?(Splat)
        node = node.exp if node.is_a?(Splat)
        @nested_block_visitor.not_nil!.accept(node)
        args = [NumberLiteral.new(location.line_number)] of ASTNode
        if node.is_a?(TupleLiteral)
          args << ArrayLiteral.new(node.elements.map { |e| StringLiteral.new(e.to_s).as(ASTNode) })
        end
        call = Call.new(Call.new("_p"), "i", args, Block.new([] of Var, node.as(ASTNode)).at(node))
        call = Cast.new(call, TypeOf.new([node.clone] of ASTNode)) if add_as_typeof
        call = Splat.new(call) if splat
        call
      else
        node
      end
    end

    def transform(node : Assign)
      # constants are Path, avoid instrumenting those assignments
      unless node.target.is_a?(Path)
        node.value = instrument(node.value, add_as_typeof: !node.target.is_a?(Var))
      end
      node
    end

    def transform(node : MultiAssign)
      node.values = if node.values.size == 1
                      [instrument(node.values[0])] of ASTNode
                    else
                      rhs = TupleLiteral.new(node.values).at(node)
                      rhs.location = node.location
                      [instrument(rhs)] of ASTNode
                    end
      node
    end

    def transform(node : NilLiteral | NumberLiteral | StringLiteral | BoolLiteral | CharLiteral | SymbolLiteral | TupleLiteral | ArrayLiteral | HashLiteral | StringInterpolation | RegexLiteral | Var | InstanceVar | ClassVar | Global | TypeOf | UnaryExpression | BinaryOp | IsA | ReadInstanceVar)
      instrument(node)
    end

    def transform(node : Call)
      case {node.obj, node.name, node.args.size}
      when {nil, "raise", 1}
        instrument_arg node
      when {nil, "puts", _}
        instrument_if_args node
      when {nil, "print", _}
        instrument_if_args node
      when {nil, _, _}
        if @macro_names.includes?(node.name)
          node
        else
          instrument(node)
        end
      else
        instrument(node)
      end
    end

    private def instrument_if_args(node : Call)
      case node.args.size
      when 0
        node
      when 1
        instrument_arg node
      else
        instrument_args_and_splat node
      end
    end

    private def instrument_arg(node : Call)
      node.args[0] = instrument(node.args[0])
      node
    end

    private def instrument_args_and_splat(node : Call)
      args = TupleLiteral.new(node.args).at(node)
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
      node.expressions = node.expressions.map(&.transform(self).as(ASTNode)).to_a
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

    def ignoring_line_of_node(node, &)
      old_ignore_line = @ignore_line
      @ignore_line = node.location.try(&.line_number)
      res = yield
      @ignore_line = old_ignore_line
      res
    end
  end
end
