#see: crystal/syntax/to_s.cr
#see: crystal/syntax/ast.cr
require "../syntax/ast"

module Crystal
  def self.print_ast(node)
    node.accept PrintASTVisitor.new
  end

  class PrintASTVisitor < Visitor
    def initialize
      @indents = [] of Bool
    end

    def end_visit(node)
      @indents.pop
    end

    def visit(node : Nop)
      puts_ast(node)
    end

    # def visit(node : Expressions)
    #   puts_ast(node)
    # end

    def visit(node : NilLiteral)
      puts_ast(node)
    end

    def visit(node : BoolLiteral)
      puts_ast(node, node.value)
    end

    def visit(node : NumberLiteral)
      puts_ast(node, "#{node.value}, KIND: #{node.kind})")
    end

    def visit(node : CharLiteral)
      puts_ast(node, node.value)
    end

    def visit(node : StringLiteral)
      puts_ast(node, node.value)
    end

    # def visit(node : StringInterpolation)
    #   puts_ast(node, node.value)
    # end

    def visit(node : SymbolLiteral)
      puts_ast(node, node.value)
    end

    def visit(node : ArrayLiteral)
      puts_ast(node)
      with_indent do
        node.name.try &.accept self
        node.elements.each &.accept self
        node.of.try &.accept self
      end
      false
    end

    def visit(node : HashLiteral)
      puts_ast(node)
      with_indent do
        node.name.try &.accept self
        node.entries.each do |entry|
          entry.key.accept self
          entry.value.accept self
        end
        if of = node.of
          of.key.accept self
          of.value.accept self
        end
      end
      false
    end

    def visit(node : RangeLiteral)
      puts_ast(node, "EXCLUSIVE: #{node.exclusive}")
      with_indent do
        node.from.accept self
        node.to.accept self
      end
      false
    end

    def visit(node : RegexLiteral)
      puts_ast(node, "OPTIONS: #{node.options}")
      with_indent do
        node.value.accept self
      end
      false
    end

    def visit(node : TupleLiteral)
      puts_ast(node)
      with_indent do
        node.elements.each &.accept self
      end
      false
    end

    # def visit(node : Var)
    #   puts_ast(node, node.name)
    # end

    def visit(node : Block)
      puts_ast(node)
      with_indent do
        node.args.each &.accept self
        node.body.accept self
      end
      false
    end

    def visit(node : Call)
      puts_ast(node, "NAME: #{node.name}, GLOBAL: #{node.global}, NAME_COLUMN_NUMBER: #{node.name_column_number}, HAS_PARENTHESIS: #{node.has_parenthesis}")
      with_indent do
        node.obj.try &.accept self
        node.args.each &.accept self
        node.named_args.try &.each &.accept self
        node.block_arg.try &.accept self
        node.block.try &.accept self
      end
      false
    end

    def visit(node : NamedArgument)
      puts_ast(node, "NAME #{node.name}")
      with_indent do
        node.value.accept self
      end
      false
    end

    def visit(node : If)
      puts_ast(node, "BINARY: #{node.binary}")
      with_indent do
        node.cond.accept self
        node.then.accept self
        node.else.accept self
      end
      false
    end

    def visit(node : Unless)
      puts_ast(node)
      with_indent do
        node.cond.accept self
        node.then.accept self
        node.else.accept self
      end
      false
    end

    def visit(node : IfDef)
      puts_ast(node)
      with_indent do
        node.cond.accept self
        node.then.accept self
        node.else.accept self
      end
      false
    end

    def visit(node : Assign)
      puts_ast(node)
      with_indent do
        node.target.accept self
        node.value.accept self
      end
      false
    end

    def visit(node : MultiAssign)
      puts_ast(node)
      with_indent do
        node.targets.each &.accept self
        node.values.each &.accept self
      end
      false
    end

    def visit(node : InstanceVar)
      puts_ast(node, "NAME: #{node.name}")
    end

    def visit(node : ReadInstanceVar)
      puts_ast(node, "NAME: #{node.name}")
      with_indent do
        node.obj.accept self
      end
      false
    end

    # def visit(node : ClassVar)
    #   puts_ast(node, "NAME: #{node.name}")
    # end

    # def visit(node : Global)
    #   puts_ast(node, "NAME: #{node.name}")
    # end

    def visit(node : BinaryOp)
      puts_ast(node)
      with_indent do
        node.left.accept self
        node.right.accept self
      end
      false
    end

    def visit(node : Arg)
      puts_ast(node, "NAME: #{node.name}")
      with_indent do
        node.default_value.try &.accept self
        node.restriction.try &.accept self
      end
      false
    end

    def visit(node : Fun)
      puts_ast(node)
      with_indent do
        node.inputs.try &.each &.accept self
        node.output.try &.accept self
      end
      false
    end

    def visit(node : BlockArg)
      puts_ast(node, "NAME: #{node.name}")
      with_indent do
        node.fun.try &.accept self
      end
      false
    end

    # def visit(node : Def)
    #   puts_ast(node, node.name)
    # end
    # def visit(node : Macro)
    #   puts_ast(node, node.name)
    # end

    def visit(node : UnaryExpression)
      puts_ast(node)
      with_indent do
        node.exp.accept self
      end
      false
    end

    def visit(node : VisibilityModifier)
      puts_ast(node, "MODIFIER: #{node.modifier}")
      with_indent do
        node.exp.accept self
      end
      false
    end

    def visit(node : IsA)
      puts_ast(node)
      with_indent do
        node.obj.accept self
        node.const.accept self
      end
      false
    end

    def visit(node : RespondsTo)
      puts_ast(node)
      with_indent do
        node.obj.accept self
        node.name.accept self
      end
      false
    end

    def visit(node : Require)
      puts_ast(node, "STRING: #{node.string}")
    end

    def visit(node : When)
      puts_ast(node)
      with_indent do
        node.conds.each &.accept self
        node.body.accept self
      end
      false
    end

    # How about `cond`!?
    def visit(node : Case)
      puts_ast(node)
      with_indent do
        node.whens.each &.accept self
        node.else.try &.accept self
      end
      false
    end

    def visit(node : ImplicitObj)
      puts_ast(node)
    end

    def visit(node : Path)
      puts_ast(node, "NAME: #{node.names}, GLOBAL: #{node.global}, NAME_LENGTH: #{node.name_length}")
    end

    # def visit(node : ClassDef)
    #   puts_ast(node, "NAME: #{node.names}, GLOBAL: #{node.global}, NAME_LENGTH: #{node.name_length}")
    # end

    # def visit(node : ModuleDef)
    #   puts_ast(node, "NAME: #{node.names}, GLOBAL: #{node.global}, NAME_LENGTH: #{node.name_length}")
    # end

    def visit(node : While)
      puts_ast(node, "RUN_ONCE: #{node.run_once}")
      with_indent do
        node.cond.accept self
        node.body.accept self
      end
      false
    end

    def visit(node : Until)
      puts_ast(node, "RUN_ONCE: #{node.run_once}")
      with_indent do
        node.cond.accept self
        node.body.accept self
      end
      false
    end

    def visit(node : Generic)
      puts_ast(node)
      with_indent do
        node.name.accept self
        node.type_vars.each &.accept self
      end
      false
    end

    def visit(node : DeclareVar)
      puts_ast(node)
      with_indent do
        node.var.accept self
        node.declared_type.accept self
      end
      false
    end

    def visit(node : Rescue)
      puts_ast(node, "NAME: #{node.name}")
      with_indent do
        node.body.accept self
        node.types.try &.each &.accept self
      end
      false
    end

    def visit(node : ExceptionHandler)
      puts_ast(node)
      with_indent do
        node.body.accept self
        node.rescues.try &.each &.accept self
        node.else.try &.accept self
        node.ensure.try &.accept self
      end
      false
    end

    def visit(node : FunLiteral)
      puts_ast(node)
      with_indent do
        node.def.accept self
      end
      false
    end

    def visit(node : ASTNode)
      str = node.responds_to?(:name) ? node.name : ""
      puts_ast(node, str)
    end

    private def puts_ast(node : ASTNode, str = "")
      unless @indents.empty?
        with_indent { print_indent }
        puts
        print_indent
      end
      print "#{node.class.to_s.split("::").last}: #{str} (#{node.location})"
      puts
      @indents.push true
    end

    def print_indent
      unless @indents.empty?
        0.upto(@indents.length - 1) do |i|
          print "   "
        end
      end
    end

    def with_indent
      @indents.push true
      yield
      @indents.pop
    end

  end
end
